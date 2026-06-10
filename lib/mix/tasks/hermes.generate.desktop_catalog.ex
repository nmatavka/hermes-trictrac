defmodule Mix.Tasks.Hermes.Generate.DesktopCatalog do
  use Mix.Task

  @shortdoc "Writes the desktop variant catalog JSON used by native clients"

  alias HermesTrictrac.DesktopCatalog

  @default_output Path.expand("shared/ui/generated/desktop-variant-catalog.json")

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    output_path =
      case args do
        [path] -> Path.expand(path)
        _ -> @default_output
      end

    output_path
    |> Path.dirname()
    |> File.mkdir_p!()

    output_path
    |> File.write!(Jason.encode_to_iodata!(DesktopCatalog.catalog(), pretty: true))

    Mix.shell().info("Wrote #{output_path}")
  end
end
