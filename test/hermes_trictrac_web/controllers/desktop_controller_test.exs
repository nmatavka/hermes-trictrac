defmodule HermesTrictracWeb.DesktopControllerTest do
  use HermesTrictracWeb.ConnCase, async: true

  test "GET /api/desktop/health exposes a bootstrap health payload", %{conn: conn} do
    conn = get(conn, "/api/desktop/health")

    payload = json_response(conn, 200)

    assert payload["ok"] == true
    assert payload["app"] == "hermes_trictrac"
    assert payload["schema_version"] == 1
    assert is_list(payload["local_variant_ids"])
    assert is_list(payload["online_variant_ids"])
    assert "backgammon" in payload["local_variant_ids"]
    assert "trictrac_en_poule" in payload["online_variant_ids"]
  end

  test "GET /api/desktop/catalog exposes the desktop catalog", %{conn: conn} do
    conn = get(conn, "/api/desktop/catalog")

    payload = json_response(conn, 200)

    assert payload["schema_version"] == 1
    assert is_list(payload["variants"])

    backgammon =
      Enum.find(payload["variants"], fn variant ->
        variant["id"] == "backgammon"
      end)

    assert backgammon["local_playable"] == true
    assert backgammon["local_ai"]["kind"] == "backgammon_ai"
  end
end
