defmodule HermesTrictrac.Rules.Trictrac.AccessStruct do
  defmacro __using__(opts) do
    fields = Keyword.fetch!(opts, :fields)

    quote bind_quoted: [fields: fields] do
      @behaviour Access
      defstruct fields

      @impl Access
      def fetch(%__MODULE__{} = data, key), do: Map.fetch(Map.from_struct(data), key)

      @impl Access
      def get_and_update(%__MODULE__{} = data, key, fun) do
        current = Map.get(data, key)

        case fun.(current) do
          {get, value} ->
            updated =
              data
              |> Map.from_struct()
              |> Map.put(key, value)
              |> then(&struct!(__MODULE__, &1))

            {get, updated}

          :pop ->
            pop(data, key)
        end
      end

      @impl Access
      def pop(%__MODULE__{} = data, key) do
        current = Map.get(data, key)

        updated =
          data
          |> Map.from_struct()
          |> Map.put(key, nil)
          |> then(&struct!(__MODULE__, &1))

        {current, updated}
      end
    end
  end
end
