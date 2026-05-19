defmodule HermesTrictracWeb.ModelAnalysisController do
  use HermesTrictracWeb, :controller

  alias HermesTrictrac.ModelAnalysis

  def parse(conn, params) do
    case ModelAnalysis.parse(params) do
      {:ok, payload} -> json(conn, payload)
      {:error, msg} -> conn |> put_status(:unprocessable_entity) |> json(%{error: msg})
    end
  end

  def run(conn, params) do
    case ModelAnalysis.run(params) do
      {:ok, payload} -> json(conn, payload)
      {:error, msg} -> conn |> put_status(:unprocessable_entity) |> json(%{error: msg})
    end
  end
end
