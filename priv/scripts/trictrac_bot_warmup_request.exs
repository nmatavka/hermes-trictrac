alias HermesTrictrac.Rules.Engine
alias HermesTrictrac.Training.TrictracBridge

project_dir =
  System.get_env("HERMES_TRICTRAC_BOT_PROJECT_DIR") ||
    Path.expand("../../trictrac_zero", __DIR__)

output_dir = System.get_env("HERMES_TRICTRAC_BOT_WARMUP_DIR") || "/tmp/trictrac_bot_warmup"
File.rm_rf!(output_dir)
File.mkdir_p!(output_dir)

session_layout = "sparse-v4-arena96x16"

known_presets = [
  %{
    id: "classique",
    variant_id: "trictrac_classique",
    experiment: "trictrac-classique",
    match_options: %{"margotEnabled" => false}
  },
  %{
    id: "classique-margot",
    variant_id: "trictrac_classique",
    experiment: "trictrac-classique-margot",
    match_options: %{"margotEnabled" => true}
  },
  %{
    id: "aecrire",
    variant_id: "trictrac_aecrire",
    experiment: "trictrac-aecrire",
    match_options: %{"margotEnabled" => false, "aEcrirePartieLength" => "12"}
  },
  %{
    id: "aecrire-margot",
    variant_id: "trictrac_aecrire",
    experiment: "trictrac-aecrire-margot",
    match_options: %{"margotEnabled" => true, "aEcrirePartieLength" => "12"}
  },
  %{
    id: "combine",
    variant_id: "trictrac_combine",
    experiment: "trictrac-combine",
    match_options: %{"margotEnabled" => false, "aEcrirePartieLength" => "12"}
  },
  %{
    id: "combine-margot",
    variant_id: "trictrac_combine",
    experiment: "trictrac-combine-margot",
    match_options: %{"margotEnabled" => true, "aEcrirePartieLength" => "12"}
  },
  %{
    id: "toc",
    variant_id: "toc",
    experiment: "toc",
    match_options: %{"margotEnabled" => false, "holeTarget" => "7", "doublesMode" => "off"}
  },
  %{
    id: "toc-margot",
    variant_id: "toc",
    experiment: "toc-margot",
    match_options: %{"margotEnabled" => true, "holeTarget" => "7", "doublesMode" => "off"}
  },
  %{
    id: "toccategli",
    variant_id: "toccategli",
    experiment: "toccategli",
    match_options: %{"margotEnabled" => false}
  },
  %{
    id: "toccategli-margot",
    variant_id: "toccategli",
    experiment: "toccategli-margot",
    match_options: %{"margotEnabled" => true}
  }
]

default_session_dir = fn preset ->
  Path.join(project_dir, "sessions/#{preset.experiment}-#{session_layout}")
end

known_presets =
  Enum.map(known_presets, fn preset ->
    Map.put(preset, :session_dir, default_session_dir.(preset))
  end)

infer_session_preset = fn session_dir ->
  session_name = Path.basename(session_dir)
  margot_enabled = String.contains?(session_name, "margot")

  inferred =
    cond do
      String.starts_with?(session_name, "trictrac-classique") ->
        %{
          variant_id: "trictrac_classique",
          match_options: %{"margotEnabled" => margot_enabled}
        }

      String.starts_with?(session_name, "trictrac-aecrire") ->
        %{
          variant_id: "trictrac_aecrire",
          match_options: %{
            "margotEnabled" => margot_enabled,
            "aEcrirePartieLength" => "12"
          }
        }

      String.starts_with?(session_name, "trictrac-combine") ->
        %{
          variant_id: "trictrac_combine",
          match_options: %{
            "margotEnabled" => margot_enabled,
            "aEcrirePartieLength" => "12"
          }
        }

      String.starts_with?(session_name, "toccategli") ->
        %{
          variant_id: "toccategli",
          match_options: %{"margotEnabled" => margot_enabled}
        }

      String.starts_with?(session_name, "toc") ->
        %{
          variant_id: "toc",
          match_options: %{
            "margotEnabled" => margot_enabled,
            "holeTarget" => "7",
            "doublesMode" => "off"
          }
        }

      true ->
        nil
    end

  if is_nil(inferred) do
    nil
  else
    id =
      session_name
      |> String.replace(~r/[^A-Za-z0-9_-]+/, "-")
      |> String.trim("-")

    inferred
    |> Map.put(:id, id)
    |> Map.put(:experiment, session_name)
    |> Map.put(:session_dir, session_dir)
  end
end

known_session_dirs = known_presets |> Enum.map(& &1.session_dir) |> MapSet.new()

extra_presets =
  Path.join(project_dir, "sessions/*/bestnn.data")
  |> Path.wildcard()
  |> Enum.map(&Path.dirname/1)
  |> Enum.reject(&MapSet.member?(known_session_dirs, &1))
  |> Enum.flat_map(fn session_dir ->
    case infer_session_preset.(session_dir) do
      nil ->
        IO.puts(
          "Skipping TricTracZero warmup session #{session_dir}: could not infer a warmup variant"
        )

        []

      preset ->
        [preset]
    end
  end)

presets = known_presets ++ extra_presets

submit_pending_options = fn engine, options, user, client_id ->
  case engine.pending_match_options do
    %{"kind" => "trictrac_margot_consent"} ->
      consent = if options["margotEnabled"], do: "yes", else: "no"
      Engine.submit_match_options(engine, %{"margotConsent" => consent}, user, client_id)

    %{"kind" => "trictrac_partie_length_consent"} ->
      length = Map.get(options, "aEcrirePartieLength", "12")

      Engine.submit_match_options(
        engine,
        %{"aEcrirePartieLengthConsent" => length},
        user,
        client_id
      )

    nil ->
      {:ok, engine}

    %{"kind" => kind} ->
      {:error, "Unsupported warmup pending option kind: #{kind}"}
  end
end

settle_pending_options = fn engine, options ->
  Enum.reduce_while(1..8, engine, fn _step, current ->
    if is_nil(current.pending_match_options) do
      {:halt, current}
    else
      with {:ok, current} <-
             submit_pending_options.(current, options, "white", "bot-warmup-white"),
           {:ok, current} <-
             submit_pending_options.(current, options, "black", "bot-warmup-black") do
        {:cont, current}
      else
        {:error, msg} -> raise msg
      end
    end
  end)
end

complete_opening = fn engine ->
  Enum.reduce_while(1..16, engine, fn _step, current ->
    cond do
      not is_nil(current.turn_color) ->
        {:halt, current}

      true ->
        {:ok, current} = Engine.roll(current, "white", "bot-warmup-white")
        {:ok, current} = Engine.roll(current, "black", "bot-warmup-black")
        {:cont, current}
    end
  end)
end

build_request = fn preset ->
  engine =
    "bot-warmup-#{preset.id}"
    |> Engine.new(preset.variant_id)
    |> Engine.seed_match_options(preset.match_options)

  {:ok, engine, _player} = Engine.join(engine, "white", "bot-warmup-white")
  {:ok, engine, _player} = Engine.join(engine, "black", "bot-warmup-black")

  engine =
    engine
    |> settle_pending_options.(preset.match_options)
    |> complete_opening.()

  %{
    "id" => 1,
    "cmd" => "choose_action",
    "state" => TrictracBridge.serialize_state(Engine.runtime_view(engine))
  }
end

session_entries =
  presets
  |> Enum.flat_map(fn preset ->
    session_dir = preset.session_dir

    if File.regular?(Path.join(session_dir, "bestnn.data")) do
      request_path = Path.join(output_dir, "#{preset.id}.jsonl")
      File.write!(request_path, Jason.encode!(build_request.(preset)) <> "\n")
      ["#{preset.id}|#{session_dir}|#{request_path}"]
    else
      IO.puts(
        "Skipping TricTracZero warmup preset #{preset.id}: no bestnn.data at #{session_dir}"
      )

      []
    end
  end)

if session_entries == [] do
  raise "No TricTracZero model sessions were found to warm."
end

File.write!(Path.join(output_dir, "sessions.list"), Enum.join(session_entries, "\n") <> "\n")
