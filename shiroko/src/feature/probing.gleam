import feature/probing/health
import feature/probing/router
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
    ["probe"] -> router.page_list(req, registry)
    ["api", "probe", service] -> router.api_show(req, service, registry)
    _ -> wisp.not_found()
  }
}
