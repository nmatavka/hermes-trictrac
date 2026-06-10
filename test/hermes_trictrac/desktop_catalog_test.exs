defmodule HermesTrictrac.DesktopCatalogTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.DesktopCatalog

  test "catalog exposes the schema version and serialized variants" do
    catalog = DesktopCatalog.catalog()

    assert catalog["schema_version"] == DesktopCatalog.schema_version()
    assert is_list(catalog["variants"])
    assert Enum.any?(catalog["variants"], &(&1["id"] == "backgammon"))
  end

  test "backgammon is locally playable with bundled BackgammonAI" do
    backgammon = DesktopCatalog.variants() |> Enum.find(&(&1.id == "backgammon"))

    assert backgammon.local_playable
    assert backgammon.online_playable
    assert backgammon.local_ai["available"] == true
    assert backgammon.local_ai["kind"] == "backgammon_ai"
  end

  test "session tables stay online-capable but local-only play is disabled" do
    session_variants =
      DesktopCatalog.variants()
      |> Enum.filter(&(!is_nil(&1.session_mode)))

    assert session_variants != []
    assert Enum.all?(session_variants, &(&1.online_playable and not &1.local_playable))
  end

  test "known bundled trictrac model sessions are exposed through the AI catalog" do
    classique = DesktopCatalog.variants() |> Enum.find(&(&1.id == "trictrac_classique"))

    assert classique.local_playable
    assert classique.local_ai["kind"] in ["trictrac_zero", nil]
    assert is_list(classique.local_ai["presets"])
  end
end
