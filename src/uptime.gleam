import uptime/health

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
