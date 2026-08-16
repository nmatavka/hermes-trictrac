defmodule HermesTrictrac.DesktopCatalogTest do
  use ExUnit.Case, async: true

  alias HermesTrictrac.DesktopCatalog

  test "catalog exposes the schema version and serialized variants" do
    catalog = DesktopCatalog.catalog()

    assert catalog["schema_version"] == DesktopCatalog.schema_version()
    assert is_list(catalog["variants"])
    assert Enum.any?(catalog["variants"], &(&1["id"] == "backgammon"))
    assert [first_format | _rest] = get_in(catalog, ["lobby", "multi_seat_formats"])
    assert first_format["id"] == "trictrac_en_poule"
    assert Enum.map(first_format["join_fields"], & &1["id"]) == ["queue_size", "ante", "margot_enabled"]
  end

  test "top-rail games remain playable by people while their zero champion is unreleased" do
    backgammon = DesktopCatalog.variants() |> Enum.find(&(&1.id == "backgammon"))

    assert backgammon.local_playable
    assert backgammon.online_playable
    assert backgammon.local_ai["available"] == false
    assert backgammon.local_ai["kind"] == "backgammon_zero"
    assert backgammon.menu_section == "primary"
    assert backgammon.menu_rank == 0
    assert backgammon.menu_label == "Backgammon"
  end

  test "tavli is a separately described fixed-order composite" do
    tavli = DesktopCatalog.variants() |> Enum.find(&(&1.id == "tavli"))

    assert tavli.local_playable
    assert tavli.online_playable
    assert tavli.menu_section == "composite"
    assert tavli.selection_mode == "composite"
    assert tavli.members == ["backgammon", "tapa", "jacquet"]
    assert tavli.local_ai["kind"] == "tavli_zero"
    assert tavli.local_ai["available"] == false
  end

  test "the lower rail is explicitly human-only" do
    aecrire = DesktopCatalog.variants() |> Enum.find(&(&1.id == "trictrac_aecrire"))
    combine = DesktopCatalog.variants() |> Enum.find(&(&1.id == "trictrac_combine"))

    assert aecrire.menu_section == "more"
    assert combine.menu_section == "more"
    assert aecrire.local_ai["available"] == false
    assert combine.local_ai["available"] == false
    assert is_nil(aecrire.local_ai["kind"])
    assert is_nil(combine.local_ai["kind"])
  end

  test "session tables are included in the bundled local runtime catalog" do
    session_variants =
      DesktopCatalog.variants()
      |> Enum.filter(&(!is_nil(&1.session_mode)))

    assert session_variants != []
    assert Enum.all?(session_variants, &(&1.online_playable and &1.local_playable))
  end

  test "known bundled trictrac model sessions are exposed through the AI catalog" do
    classique = DesktopCatalog.variants() |> Enum.find(&(&1.id == "trictrac_classique"))

    assert classique.local_playable
    assert classique.local_ai["kind"] in ["trictrac_zero", nil]
    assert is_list(classique.local_ai["presets"])
  end
end
