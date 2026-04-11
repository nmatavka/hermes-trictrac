using Base: @kwdef
import AlphaZero: Flux, Network

@kwdef struct TricTracSparseNetHP
  num_blocks::Int
  num_filters::Int
  conv_kernel_size::Tuple{Int, Int}
  num_policy_head_filters::Int = 16
  num_value_head_filters::Int = 16
  policy_hidden_dim::Int = 64
  batch_norm_momentum::Float32 = 0.1f0
end

mutable struct TricTracSparseNet <: AlphaZero.FluxLib.FluxNetwork
  gspec
  hyper
  common
  state_head
  action_head
  value_head
end

function legacy_network_layout(nn::TricTracSparseNet)
  if getfield(nn, :value_head) isa TricTracSparseNetHP
    return :hyper_last
  elseif getfield(nn, :hyper) isa String && getfield(nn, :common) isa TricTracSparseNetHP
    return :dropped_value_head
  else
    return nothing
  end
end

function Base.getproperty(nn::TricTracSparseNet, name::Symbol)
  layout = legacy_network_layout(nn)

  if isnothing(layout)
    return getfield(nn, name)
  end

  if layout === :hyper_last
    if name === :gspec
      return getfield(nn, :gspec)
    elseif name === :hyper
      return getfield(nn, :value_head)
    elseif name === :common
      return getfield(nn, :hyper)
    elseif name === :state_head
      return getfield(nn, :common)
    elseif name === :action_head
      return getfield(nn, :state_head)
    elseif name === :value_head
      return getfield(nn, :action_head)
    end
  elseif layout === :dropped_value_head
    if name === :gspec
      return getfield(nn, :gspec)
    elseif name === :hyper
      return getfield(nn, :common)
    elseif name === :common
      return getfield(nn, :state_head)
    elseif name === :state_head
      return getfield(nn, :action_head)
    elseif name === :action_head
      return getfield(nn, :value_head)
    elseif name === :value_head
      return nothing
    end
  end

  return getfield(nn, name)
end

function TricTracSparseNet(gspec::GI.AbstractGameSpec, hyper::TricTracSparseNetHP)
  indim = GI.state_dim(gspec)
  ksize = hyper.conv_kernel_size
  @assert all(ksize .% 2 .== 1)
  pad = ksize .÷ 2
  nf = hyper.num_filters
  npf = hyper.num_policy_head_filters
  nvf = hyper.num_value_head_filters
  hidden = hyper.policy_hidden_dim
  bnmom = hyper.batch_norm_momentum

  common = Flux.Chain(
    Flux.Conv(ksize, indim[3] => nf, pad = pad),
    Flux.BatchNorm(nf, Flux.relu, momentum = bnmom),
    [AlphaZero.FluxLib.ResNetBlock(ksize, nf, bnmom) for _ in 1:hyper.num_blocks]...
  )

  state_head = Flux.Chain(
    Flux.Conv((1, 1), nf => npf),
    Flux.BatchNorm(npf, Flux.relu, momentum = bnmom),
    Flux.flatten,
    Flux.Dense(indim[1] * indim[2] * npf, hidden, Flux.relu)
  )

  action_head = Flux.Chain(
    Flux.Dense(NUM_ACTION_FEATURES, hidden, Flux.relu),
    Flux.Dense(hidden, hidden, Flux.relu)
  )

  value_head = Flux.Chain(
    Flux.Conv((1, 1), nf => nvf),
    Flux.BatchNorm(nvf, Flux.relu, momentum = bnmom),
    Flux.flatten,
    Flux.Dense(indim[1] * indim[2] * nvf, nf, Flux.relu),
    Flux.Dense(nf, 1, tanh)
  )

  return TricTracSparseNet(gspec, hyper, common, state_head, action_head, value_head)
end

Network.HyperParams(::Type{<:TricTracSparseNet}) = TricTracSparseNetHP
Network.hyperparams(nn::TricTracSparseNet) = nn.hyper
Network.game_spec(nn::TricTracSparseNet) = nn.gspec
function Network.on_gpu(nn::TricTracSparseNet)
  head = nn.value_head
  if isnothing(head)
    return AlphaZero.FluxLib.array_on_gpu(nn.action_head[end].bias)
  end
  return AlphaZero.FluxLib.array_on_gpu(head[end].bias)
end

function sparse_policy_forward(nn::TricTracSparseNet, X, F, M)
  common = nn.common(X)
  state_hidden = nn.state_head(common)
  action_hidden = nn.action_head(F)
  state_hidden = reshape(state_hidden, size(state_hidden, 1), 1, size(state_hidden, 2))
  scores = dropdims(sum(state_hidden .* action_hidden; dims = 1); dims = 1)
  if isnothing(nn.value_head)
    V = zeros(eltype(scores), 1, size(scores, 2))
  else
    V = nn.value_head(common)
  end
  masked_scores = scores .+ (M .- one(eltype(M))) .* 1f9
  P = Flux.softmax(masked_scores; dims = 1)
  P = P .* M
  P = P ./ (sum(P; dims = 1) .+ eps(eltype(P)))
  p_invalid = zeros(eltype(P), 1, size(P, 2))
  return (P, V, p_invalid)
end

function sparse_policy_batch(gspec::TricTracGameSpec, states::AbstractVector{TricTracState})
  X = Flux.batch([GI.vectorize_state(gspec, state) for state in states])
  actions = [state_catalog_actions(state) for state in states]
  max_actions = isempty(actions) ? 0 : maximum(length, actions)
  F = zeros(Float32, NUM_ACTION_FEATURES, max_actions, length(states))
  M = zeros(Float32, max_actions, length(states))

  for (index, state_actions) in pairs(actions)
    isempty(state_actions) && continue
    features = legal_action_features(state_actions)
    nactions = size(features, 2)
    F[:, 1:nactions, index] = features
    M[1:nactions, index] .= 1f0
  end

  return (; X, F, M, actions)
end

function state_value_only(nn::TricTracSparseNet, state::TricTracState)
  isnothing(nn.value_head) && return 0.0
  x = GI.vectorize_state(nn.gspec, state)
  x = reshape(x, size(x)..., 1)
  xnet = Network.convert_input(nn, x)
  value = nn.value_head(nn.common(xnet))
  value = Network.convert_output(nn, value)
  return Float64(value[1])
end

function Network.evaluate(nn::TricTracSparseNet, state::TricTracState)
  actions = state_catalog_actions(state)
  isempty(actions) && return (Float32[], state_value_only(nn, state))

  batch = sparse_policy_batch(nn.gspec, [state])
  Xnet, Fnet, Mnet = Network.convert_input_tuple(nn, (batch.X, batch.F, batch.M))
  P, V, _ = sparse_policy_forward(nn, Xnet, Fnet, Mnet)
  P, V = Network.convert_output_tuple(nn, (P, V))
  return (Vector{Float32}(P[1:length(actions), 1]), Float64(V[1]))
end

function Network.evaluate_batch(nn::TricTracSparseNet, states)
  states = collect(states)
  isempty(states) && return Tuple{Vector{Float32}, Float64}[]

  batch = sparse_policy_batch(nn.gspec, states)
  max_actions = size(batch.M, 1)
  if iszero(max_actions)
    return [Network.evaluate(nn, state) for state in states]
  end

  Xnet, Fnet, Mnet = Network.convert_input_tuple(nn, (batch.X, batch.F, batch.M))
  P, V, _ = sparse_policy_forward(nn, Xnet, Fnet, Mnet)
  P, V = Network.convert_output_tuple(nn, (P, V))

  return [
    (Vector{Float32}(P[1:length(actions), index]), Float64(V[1, index]))
    for (index, actions) in pairs(batch.actions)
  ]
end

function AlphaZero.convert_sample(
  gspec::TricTracGameSpec,
  wp::AlphaZero.SamplesWeighingPolicy,
  e::AlphaZero.TrainingSample{TricTracState}
)
  if wp == AlphaZero.CONSTANT_WEIGHT
    w = Float32[1]
  elseif wp == AlphaZero.LOG_WEIGHT
    w = Float32[log2(e.n) + 1]
  else
    @assert wp == AlphaZero.LINEAR_WEIGHT
    w = Float32[e.n]
  end

  actions = state_catalog_actions(e.s)
  x = GI.vectorize_state(gspec, e.s)
  f = legal_action_features(actions)
  m = ones(Float32, length(actions))
  p = Float32.(e.π)
  v = Float32[e.z]
  return (; w, x, f, m, p, v)
end

function AlphaZero.convert_samples(
  gspec::TricTracGameSpec,
  wp::AlphaZero.SamplesWeighingPolicy,
  es::AbstractVector{<:AlphaZero.TrainingSample{TricTracState}}
)
  ces = [AlphaZero.convert_sample(gspec, wp, sample) for sample in es]
  W = convert(AbstractArray{Float32}, Flux.batch([entry.w for entry in ces]))
  X = convert(AbstractArray{Float32}, Flux.batch([entry.x for entry in ces]))
  V = convert(AbstractArray{Float32}, Flux.batch([entry.v for entry in ces]))

  max_actions = isempty(ces) ? 0 : maximum(size(entry.f, 2) for entry in ces)
  F = zeros(Float32, NUM_ACTION_FEATURES, max_actions, length(ces))
  M = zeros(Float32, max_actions, length(ces))
  P = zeros(Float32, max_actions, length(ces))

  for (index, entry) in pairs(ces)
    nactions = size(entry.f, 2)
    nactions == 0 && continue
    F[:, 1:nactions, index] = entry.f
    M[1:nactions, index] = entry.m
    P[1:nactions, index] = entry.p
  end

  return (; W, X, F, M, P, V)
end

function AlphaZero.losses(
  nn::TricTracSparseNet,
  params,
  Wmean,
  Hp,
  batch::NamedTuple{(:W, :X, :F, :M, :P, :V), T}
) where {T <: Tuple}
  W, X, F, M, P, V = batch
  regws = Network.params(nn)
  creg = params.l2_regularization
  cinv = params.nonvalidity_penalty
  P̂, V̂, p_invalid = sparse_policy_forward(nn, X, F, M)
  V = V ./ params.rewards_renormalization
  V̂ = V̂ ./ params.rewards_renormalization
  Lp = AlphaZero.klloss_wmean(P̂, P, W) - Hp
  Lv = AlphaZero.mse_wmean(V̂, V, W)
  Lreg = iszero(creg) ? zero(Lv) : creg * sum(sum(w .* w) for w in regws)
  Linv = iszero(cinv) ? zero(Lv) : cinv * AlphaZero.wmean(p_invalid, W)
  L = ((sum(W) / length(W)) / Wmean) * (Lp + Lv + Lreg + Linv)
  return (L, Lp, Lv, Lreg, Linv)
end

function AlphaZero.learning_status(
  tr::AlphaZero.Trainer,
  samples::NamedTuple{(:W, :X, :F, :M, :P, :V), T}
) where {T <: Tuple}
  W = samples.W
  Ls = AlphaZero.losses(tr.network, tr.params, tr.Wmean, tr.Hp, samples)
  Pnet, _, _ = sparse_policy_forward(tr.network, samples.X, samples.F, samples.M)
  Hpnet = AlphaZero.entropy_wmean(Pnet, W)
  Ls = Network.convert_output_tuple(tr.network, Ls)
  Hpnet = Network.convert_output(tr.network, Hpnet)
  return AlphaZero.Report.LearningStatus(AlphaZero.Report.Loss(Ls...), tr.Hp, Hpnet)
end
