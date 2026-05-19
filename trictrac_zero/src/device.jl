import AlphaZero: Flux

const DEVICE_CPU = :cpu
const DEVICE_CUDA = :cuda
const DEVICE_METAL = :metal
const DEVICE_AUTO = :auto
const VALID_DEVICE_BACKENDS = (DEVICE_CPU, DEVICE_CUDA, DEVICE_METAL, DEVICE_AUTO)
const ACTIVE_DEVICE_BACKEND = Ref{Symbol}(DEVICE_CPU)

@static if Sys.isapple()
  import Metal
  const HAS_METAL_PACKAGE = true
else
  const HAS_METAL_PACKAGE = false
end

normalize_device_backend(device::Symbol) = normalize_device_backend(String(device))

function normalize_device_backend(device::AbstractString)
  backend = Symbol(lowercase(strip(device)))
  backend in VALID_DEVICE_BACKENDS && return backend
  choices = join(String.(VALID_DEVICE_BACKENDS), ", ")
  error("Unsupported device backend $(repr(String(device))). Expected one of: $choices.")
end

is_gpu_backend(backend::Symbol) = backend in (DEVICE_CUDA, DEVICE_METAL)

function apple_silicon_host()
  return Sys.isapple() && Sys.ARCH in (:aarch64, :arm64)
end

function device_available(backend::Symbol)
  backend = normalize_device_backend(backend)
  backend == DEVICE_CPU && return true
  backend == DEVICE_CUDA && return AlphaZero.FluxLib.CUDA.functional()
  backend == DEVICE_METAL && return HAS_METAL_PACKAGE && Metal.functional()
  backend == DEVICE_AUTO && return resolve_device_backend(DEVICE_AUTO) != DEVICE_CPU
  return false
end

device_available(backend::AbstractString) = device_available(normalize_device_backend(backend))

function resolve_device_backend(requested::Symbol = DEVICE_CPU)
  requested = normalize_device_backend(requested)

  if requested == DEVICE_AUTO
    if apple_silicon_host() && device_available(DEVICE_METAL)
      return DEVICE_METAL
    elseif device_available(DEVICE_CUDA)
      return DEVICE_CUDA
    elseif device_available(DEVICE_METAL)
      return DEVICE_METAL
    else
      return DEVICE_CPU
    end
  end

  return requested
end

resolve_device_backend(requested::AbstractString) = resolve_device_backend(normalize_device_backend(requested))

function require_device_available(requested::Symbol)
  requested = normalize_device_backend(requested)
  requested == DEVICE_AUTO && return resolve_device_backend(DEVICE_AUTO)
  device_available(requested) && return requested

  if requested == DEVICE_CUDA
    error("CUDA was requested, but CUDA.functional() is false in this environment.")
  elseif requested == DEVICE_METAL
    if !HAS_METAL_PACKAGE
      error("Metal was requested, but Metal.jl is only available on Apple hosts.")
    end
    error("Metal was requested, but Metal.functional() is false in this environment.")
  else
    error("Unsupported explicit device request: $(requested).")
  end
end

require_device_available(requested::AbstractString) = require_device_available(normalize_device_backend(requested))

function runtime_device(backend::Symbol)
  backend = normalize_device_backend(backend)
  backend == DEVICE_CPU && return Flux.cpu_device()
  backend == DEVICE_CUDA && return Flux.CUDADevice()
  backend == DEVICE_METAL && return Flux.MetalDevice()
  error("No runtime device adaptor exists for backend $(backend).")
end

move_to_backend(value, backend::Symbol) = runtime_device(backend)(value)

function array_device_backend(value)
  devtype = Flux.MLDataDevices.get_device_type(value)
  devtype <: Flux.CUDADevice && return DEVICE_CUDA
  devtype <: Flux.MetalDevice && return DEVICE_METAL
  devtype <: Flux.CPUDevice && return DEVICE_CPU
  devtype === Nothing && return DEVICE_CPU
  return DEVICE_CPU
end

active_device_backend() = ACTIVE_DEVICE_BACKEND[]

function set_runtime_device!(requested::Symbol = DEVICE_CPU)
  resolved =
    requested == DEVICE_AUTO ?
      resolve_device_backend(DEVICE_AUTO) :
      require_device_available(requested)
  ACTIVE_DEVICE_BACKEND[] = resolved

  if resolved == DEVICE_CUDA
    AlphaZero.FluxLib.CUDA.allowscalar(false)
  elseif resolved == DEVICE_METAL && HAS_METAL_PACKAGE
    Metal.allowscalar(false)
  end

  return resolved
end

set_runtime_device!(requested::AbstractString) = set_runtime_device!(normalize_device_backend(requested))
