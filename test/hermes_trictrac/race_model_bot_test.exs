defmodule HermesTrictrac.RaceModelBotTest do
  use ExUnit.Case, async: false

  alias HermesTrictrac.RaceModelBot
  alias HermesTrictrac.ModelAnalysis

  test "each race model requires its own accepted release and checkpoint" do
    previous = Application.get_env(:hermes_trictrac, :race_model_bot)

    session =
      Path.join(System.tmp_dir!(), "tavli-model-bot-#{System.unique_integer([:positive])}")

    File.mkdir_p!(session)

    on_exit(fn ->
      Application.put_env(:hermes_trictrac, :race_model_bot, previous)
      File.rm_rf(session)
    end)

    Application.put_env(:hermes_trictrac, :race_model_bot, session_dirs: %{"tavli" => session})

    refute RaceModelBot.available?("tavli")
    refute RaceModelBot.available?("backgammon")

    File.write!(Path.join(session, "bestnn.data"), "checkpoint")
    refute RaceModelBot.available?("tavli")

    File.write!(
      Path.join(session, "race-champion.json"),
      Jason.encode!(%{
        "accepted" => true,
        "checkpoint" => "bestnn.data",
        "iteration" => 1,
        "schema" => 1,
        "variant_id" => "tavli"
      })
    )

    assert RaceModelBot.available?("tavli")
    refute RaceModelBot.available?("backgammon")
  end

  test "Jacquet Model Lab keeps the diagonal parallel coordinate convention fixed" do
    previous = Application.get_env(:hermes_trictrac, :race_model_bot)

    session =
      Path.join(System.tmp_dir!(), "jacquet-model-lab-#{System.unique_integer([:positive])}")

    File.mkdir_p!(session)
    File.write!(Path.join(session, "bestnn.data"), "checkpoint")

    File.write!(
      Path.join(session, "race-champion.json"),
      Jason.encode!(%{
        "accepted" => true,
        "checkpoint" => "bestnn.data",
        "variant_id" => "jacquet"
      })
    )

    on_exit(fn ->
      Application.put_env(:hermes_trictrac, :race_model_bot, previous)
      File.rm_rf(session)
    end)

    Application.put_env(:hermes_trictrac, :race_model_bot, session_dirs: %{"jacquet" => session})

    assert %{id: "jacquet_zero", movement_mode: "parallel", fixed_black_direction: true} =
             Enum.find(ModelAnalysis.models(), &(&1.id == "jacquet_zero"))

    assert {:ok, position} =
             ModelAnalysis.parse(%{
               "model" => "jacquet_zero",
               "xgid" => "XGID=-O----------------------o-:0:0:-1:61:0:0:0:1:0",
               "black_direction" => "toward_24"
             })

    assert position.movement_mode == "parallel"
    assert position.black_direction == "toward_1"
    assert position.white_direction == "toward_1"
  end
end
