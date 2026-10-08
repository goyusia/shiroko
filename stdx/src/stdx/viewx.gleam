import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn meta() -> Element(message) {
  element.fragment([
    html.meta([attribute.charset("utf-8")]),
    html.meta([
      attribute.name("viewport"),
      attribute.content("width=device-width, initial-scale=1"),
    ]),
  ])
}

pub fn head(title: String) -> Element(message) {
  html.head([], [meta(), html.title([], title)])
}
