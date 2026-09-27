import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view_meta() -> Element(message) {
  element.fragment([
    html.meta([attribute.charset("utf-8")]),
    html.meta([
      attribute.name("viewport"),
      attribute.content("width=device-width, initial-scale=1"),
    ]),
  ])
}

pub fn view_head(title: String) -> Element(message) {
  html.head([], [view_meta(), html.title([], title)])
}
