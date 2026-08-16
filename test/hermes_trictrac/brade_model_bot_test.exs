defmodule HermesTrictrac.BradeModelBotTest do
  use ExUnit.Case, async: false

  alias HermesTrictrac.BradeModelBot

  test "availability requires both an accepted release manifest and best checkpoint" do
    previous = Application.get_env(:hermes_trictrac, :brade_model_bot)

    session =
      Path.join(System.tmp_dir!(), "brade-model-bot-#{System.unique_integer([:positive])}")

    File.mkdir_p!(session)

    on_exit(fn ->
      Application.put_env(:hermes_trictrac, :brade_model_bot, previous)
      File.rm_rf(session)
    end)

    Application.put_env(:hermes_trictrac, :brade_model_bot, session_dir: session)
    refute BradeModelBot.available?()

    File.write!(Path.join(session, "bestnn.data"), "checkpoint")
    refute BradeModelBot.available?()

    File.write!(
      Path.join(session, "brade-champion.json"),
      Jason.encode!(%{
        "accepted" => true,
        "checkpoint" => "bestnn.data",
        "iteration" => 1,
        "schema" => 1
      })
    )

    assert BradeModelBot.available?()
  end
end
