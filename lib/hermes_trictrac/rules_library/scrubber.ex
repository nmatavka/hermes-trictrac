defmodule HermesTrictrac.RulesLibrary.Scrubber do
  use HtmlSanitizeEx, extend: :html5

  allow_tag_with_these_attributes("a", ["id", "name", "title", "rel", "target"])
  allow_tag_with_these_attributes("span", ["id", "class"])
  allow_tag_with_these_attributes("sup", ["id", "class"])
  allow_tag_with_these_attributes("li", ["id"])
  allow_tag_with_these_attributes("ol", ["id", "class"])
  allow_tag_with_these_attributes("ul", ["id", "class"])
  allow_tag_with_these_attributes("section", ["id", "class"])
  allow_tag_with_these_attributes("div", ["id", "class"])
  allow_tag_with_these_attributes("p", ["id", "class"])
  allow_tag_with_these_attributes("h1", ["id"])
  allow_tag_with_these_attributes("h2", ["id"])
  allow_tag_with_these_attributes("h3", ["id"])
  allow_tag_with_these_attributes("h4", ["id"])
  allow_tag_with_these_attributes("h5", ["id"])
  allow_tag_with_these_attributes("h6", ["id"])
end
