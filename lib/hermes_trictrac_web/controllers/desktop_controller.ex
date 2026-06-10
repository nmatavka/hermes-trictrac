defmodule HermesTrictracWeb.DesktopController do
  use HermesTrictracWeb, :controller

  alias HermesTrictrac.DesktopCatalog
  alias HermesTrictrac.Identity

  def health(conn, _params) do
    json(conn, %{
      ok: true,
      app: "hermes_trictrac",
      schema_version: DesktopCatalog.schema_version(),
      identity_mode: Identity.mode(),
      local_variant_ids: DesktopCatalog.local_variant_ids(),
      online_variant_ids: DesktopCatalog.online_variant_ids()
    })
  end

  def catalog(conn, _params) do
    json(conn, DesktopCatalog.catalog())
  end
end
