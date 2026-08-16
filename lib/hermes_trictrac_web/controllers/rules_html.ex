defmodule HermesTrictracWeb.RulesHTML do
  use HermesTrictracWeb, :html

  alias HermesTrictrac.RulesLibrary

  embed_templates "rules_html/*"

  attr :return_context, :map, required: true
  attr :query, :string, default: ""
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :language_options, :list, default: []
  attr :variant_options, :list, default: []
  slot :inner_block, required: true

  def shell(assigns) do
    ~H"""
    <div class="rules-shell">
      <div class="rules-page">
        <header class="rules-header">
          <div class="rules-header-top">
            <div>
              <p class="rules-kicker">In-game rules</p>
              <h1><%= @title %></h1>
              <%= if @subtitle do %>
                <p class="rules-subtitle"><%= @subtitle %></p>
              <% end %>
            </div>

            <%= if @return_context.return_to do %>
              <a class="rules-back-link" href={@return_context.return_to}>
                <%= @return_context.return_label || "Back to game" %>
              </a>
            <% end %>
          </div>

          <div class="rules-toolbar">
            <a class="rules-home-link" href={RulesLibrary.library_path(RulesLibrary.clear_query(@return_context))}>
              All books
            </a>

            <form class="rules-filter-form" action="/rules" method="get" data-rules-filter-form>
              <%= if @return_context.return_to do %>
                <input type="hidden" name="return_to" value={@return_context.return_to} />
                <input type="hidden" name="return_label" value={@return_context.return_label || "Back to game"} />
              <% end %>
              <%= if @query != "" do %>
                <input type="hidden" name="q" value={@query} />
              <% end %>

              <label class="rules-filter-field">
                <span>Language</span>
                <select name="lang" aria-label="Rules language">
                  <%= for option <- @language_options do %>
                    <option value={option.id} selected={@return_context.language == option.id}>
                      <%= option.label %>
                    </option>
                  <% end %>
                </select>
              </label>

              <label class="rules-filter-field">
                <span>Game type</span>
                <select name="variant_id" aria-label="Rulebook game type">
                  <option value="" selected={is_nil(@return_context.variant_id)}>All games</option>
                  <%= for option <- @variant_options do %>
                    <option value={option.id} selected={@return_context.variant_id == option.id}>
                      <%= option.label %>
                    </option>
                  <% end %>
                </select>
              </label>
            </form>

            <form class="rules-search-form" action="/rules" method="get">
              <%= if @return_context.return_to do %>
                <input type="hidden" name="return_to" value={@return_context.return_to} />
                <input type="hidden" name="return_label" value={@return_context.return_label || "Back to game"} />
              <% end %>
              <input type="hidden" name="lang" value={@return_context.language} />
              <%= if @return_context.variant_id do %>
                <input type="hidden" name="variant_id" value={@return_context.variant_id} />
              <% end %>

              <input
                class="rules-search-input"
                type="search"
                name="q"
                value={@query}
                placeholder="Search all books"
                aria-label="Search all books"
              />
              <button type="submit">Search</button>
            </form>

            <button type="button" class="sound-toggle theme-cycle-button rules-theme-button" data-theme-cycle data-i18n="themeCycle" data-i18n-aria-label="themeCycle">
              Cycle Theme
            </button>
          </div>
        </header>

        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
