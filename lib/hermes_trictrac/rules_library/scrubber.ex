defmodule HermesTrictrac.RulesLibrary.Scrubber do
  use HtmlSanitizeEx, extend: :html5

  allow_tag_with_these_attributes("a", [
    "id",
    "name",
    "title",
    "rel",
    "target",
    "class",
    "aria-label",
    "data-footnote-backref",
    "data-footnote-backref-idx"
  ])

  allow_tag_with_these_attributes("span", ["id", "class"])
  allow_tag_with_these_attributes("sup", ["id", "class", "data-footnote-ref"])
  allow_tag_with_these_attributes("li", ["id", "class"])
  allow_tag_with_these_attributes("ol", ["id", "class", "start"])
  allow_tag_with_these_attributes("ul", ["id", "class"])
  allow_tag_with_these_attributes("section", ["id", "class", "data-footnotes"])
  allow_tag_with_these_attributes("div", ["id", "class"])
  allow_tag_with_these_attributes("p", ["id", "class"])
  allow_tag_with_these_attributes("input", ["type", "checked", "disabled"])
  allow_tag_with_these_attributes("code", ["class"])
  allow_tag_with_these_attributes("pre", ["class"])
  allow_tag_with_these_attributes("table", ["class"])
  allow_tag_with_these_attributes("thead", ["class"])
  allow_tag_with_these_attributes("tbody", ["class"])
  allow_tag_with_these_attributes("tfoot", ["class"])
  allow_tag_with_these_attributes("tr", ["class"])
  allow_tag_with_these_attributes("th", ["class", "colspan", "rowspan", "align"])
  allow_tag_with_these_attributes("td", ["class", "colspan", "rowspan", "align"])
  allow_tag_with_these_attributes("h1", ["id"])
  allow_tag_with_these_attributes("h2", ["id"])
  allow_tag_with_these_attributes("h3", ["id"])
  allow_tag_with_these_attributes("h4", ["id"])
  allow_tag_with_these_attributes("h5", ["id"])
  allow_tag_with_these_attributes("h6", ["id"])
end
