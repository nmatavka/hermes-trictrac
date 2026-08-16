defmodule HermesTrictrac.ModelAnalysisBradeTest do
  use ExUnit.Case, async: false

  alias HermesTrictrac.ModelAnalysis

  @starting_xgid "XGID=-O----------------------o-:0:0:-1:61:0:0:0:1:0"

  test "Bräde Model Lab fixes Jacquet-parallel direction once a champion is released" do
    previous = Application.get_env(:hermes_trictrac, :brade_model_bot)

    session =
      Path.join(System.tmp_dir!(), "brade-model-lab-#{System.unique_integer([:positive])}")

    File.mkdir_p!(session)
    File.write!(Path.join(session, "bestnn.data"), "checkpoint")

    File.write!(
      Path.join(session, "brade-champion.json"),
      Jason.encode!(%{"accepted" => true, "checkpoint" => "bestnn.data"})
    )

    on_exit(fn ->
      Application.put_env(:hermes_trictrac, :brade_model_bot, previous)
      File.rm_rf(session)
    end)

    Application.put_env(:hermes_trictrac, :brade_model_bot, session_dir: session)

    assert %{id: "brade_zero", fixed_black_direction: true} =
             Enum.find(ModelAnalysis.models(), &(&1.id == "brade_zero"))

    assert {:ok, position} =
             ModelAnalysis.parse(%{
               "model" => "brade_zero",
               "xgid" => @starting_xgid,
               "black_direction" => "toward_1"
             })

    assert position.black_direction == "toward_24"
    assert position.movement_mode == "parallel"
  end
end
