defmodule HermesTrictrac.RulesLibrary.Markdown do
  @moduledoc false

  # Keep source HTML long enough to preserve historical named anchors.  The
  # RulesLibrary passes the result through its allow-list scrubber before it is
  # served, so this is not an opt-out from sanitisation.
  @gfm_options [
    extension: [
      autolink: true,
      footnotes: true,
      strikethrough: true,
      table: true,
      tagfilter: true,
      tasklist: true
    ],
    parse: [relaxed_autolinks: true, relaxed_tasklist_matching: true],
    render: [unsafe: true, github_pre_lang: true, full_info_string: true]
  ]

  def to_html!(markdown) when is_binary(markdown), do: MDEx.to_html!(markdown, @gfm_options)
end
