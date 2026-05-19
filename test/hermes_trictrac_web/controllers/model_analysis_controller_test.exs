defmodule HermesTrictracWeb.ModelAnalysisControllerTest do
  use HermesTrictracWeb.ConnCase, async: true

  @starting_xgid "XGID=-O----------------------o-:0:0:-1:61:0:0:0:1:0"
  @bar_xgid "XGID=m------------------------M:0:0:-1:66:0:0:0:0:10"

  test "POST /dev/model-lab/parse returns a board payload", %{conn: conn} do
    conn = post(conn, "/dev/model-lab/parse", %{xgid: @starting_xgid})

    assert %{
             "dice" => [6, 1],
             "turn_color" => "white",
             "uses_bar" => false,
             "board" => %{"points" => points}
           } = json_response(conn, 200)

    assert List.first(points) == %{"black" => 15, "display" => 24, "index" => 0, "white" => 0}
    assert List.last(points) == %{"black" => 0, "display" => 1, "index" => 23, "white" => 15}
  end

  test "POST /dev/model-lab/parse can override side to play", %{conn: conn} do
    conn = post(conn, "/dev/model-lab/parse", %{xgid: @starting_xgid, turn_color: "black"})

    assert %{"turn_color" => "black"} = json_response(conn, 200)
  end

  test "POST /dev/model-lab/parse reports model movement and chosen directions", %{conn: conn} do
    conn =
      post(conn, "/dev/model-lab/parse", %{
        xgid: @starting_xgid,
        model: "trictrac_zero:classique",
        black_direction: "toward_1"
      })

    assert %{
             "movement_mode" => "contrary",
             "black_direction" => "toward_1",
             "white_direction" => "toward_24"
           } = json_response(conn, 200)
  end

  test "POST /dev/model-lab/parse derives opposite-direction play for contrary models", %{
    conn: conn
  } do
    conn =
      post(conn, "/dev/model-lab/parse", %{
        xgid: @starting_xgid,
        model: "backgammon_ai",
        black_direction: "toward_24"
      })

    assert %{
             "movement_mode" => "contrary",
             "black_direction" => "toward_24",
             "white_direction" => "toward_1"
           } = json_response(conn, 200)
  end

  test "POST /dev/model-lab/parse permits bar positions for bar variants", %{conn: conn} do
    conn = post(conn, "/dev/model-lab/parse", %{xgid: @bar_xgid, model: "backgammon_ai"})

    assert %{"uses_bar" => true, "board" => %{"bar" => %{"white" => 13, "black" => 13}}} =
             json_response(conn, 200)
  end

  test "POST /dev/model-lab/parse rejects bar positions for no-bar variants", %{conn: conn} do
    conn =
      post(conn, "/dev/model-lab/parse", %{
        xgid: @bar_xgid,
        model: "trictrac_zero:classique"
      })

    assert %{"error" => error} = json_response(conn, 422)
    assert error =~ "does not use a bar"
  end

  test "GET /dev/model-lab renders the unlinked test page", %{conn: conn} do
    conn = get(conn, "/dev/model-lab")

    body = html_response(conn, 200)
    assert body =~ ~s(id="model-lab-root")
    assert body =~ @starting_xgid

    assert body =~
             ~r/<option[^>]*value="trictrac_zero:classique"[^>]*selected|<option[^>]*selected[^>]*value="trictrac_zero:classique"/
  end
end
