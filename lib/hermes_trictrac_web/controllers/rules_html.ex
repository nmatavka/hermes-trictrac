defmodule HermesTrictracWeb.RulesHTML do
  use HermesTrictracWeb, :html

  alias HermesTrictrac.RulesLibrary

  embed_templates "rules_html/*"

  attr :return_context, :map, required: true
  attr :query, :string, default: ""
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true

  def shell(assigns) do
    ~H"""
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

          <form class="rules-search-form" action="/rules" method="get">
            <%= if @return_context.return_to do %>
              <input type="hidden" name="return_to" value={@return_context.return_to} />
              <input type="hidden" name="return_label" value={@return_context.return_label || "Back to game"} />
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
        </div>
      </header>

      <%= render_slot(@inner_block) %>
    </div>
    """
  end
end
