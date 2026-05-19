defmodule HermesTrictrac.Rules.Trictrac.Classique.Events.RuleResult do
  alias HermesTrictrac.Rules.Trictrac.Classique.Events.Context

  defstruct events: [], context: %{}

  @type t :: %__MODULE__{
          events: [term()],
          context: Context.t() | map()
        }

  @spec new(Context.t() | map()) :: t()
  def new(context), do: %__MODULE__{context: context}

  @spec add_events(t(), [term()]) :: t()
  def add_events(%__MODULE__{} = result, []), do: result

  def add_events(%__MODULE__{} = result, events) when is_list(events),
    do: %{result | events: result.events ++ events}

  @spec update_context(t(), (Context.t() | map() -> Context.t() | map())) :: t()
  def update_context(%__MODULE__{} = result, fun),
    do: %{result | context: fun.(result.context)}
end
