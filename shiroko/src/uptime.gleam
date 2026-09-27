import uptime/health
import uptime/router
import wisp.{type Request, type Response}

pub type Endpoint =
  health.Endpoint

pub type EndpointRegistry =
  health.EndpointRegistry

pub fn http(name: String, url: String, interval: Int) -> Endpoint {
  health.Http(name: name, url: url, interval: interval)
}

pub fn new(endpoints: List(Endpoint)) -> EndpointRegistry {
  health.new(endpoints)
}

pub fn supervised(registry: EndpointRegistry) {
  health.supervised(registry)
}

pub fn handle_request(req: Request, registry: EndpointRegistry) -> Response {
  case wisp.path_segments(req) {
    ["uptime"] -> router.page_list(req, registry)
    ["api", "uptime", service] -> router.api_show(req, service, registry)
    _ -> wisp.not_found()
  }
}
