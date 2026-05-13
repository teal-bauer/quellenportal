module IconHelper
  # Lucide icon paths (lucide.dev). Stroke-based, 24x24 viewbox.
  # Add icons by appending to this hash.
  PATHS = {
    copy: %(<rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>),
    download: %(<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>),
    "external-link": %(<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/>),
    search: %(<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>),
    x: %(<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>),
    "arrow-right": %(<line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>)
  }.freeze

  def icon(name, size: 16, label: nil)
    paths = PATHS.fetch(name.to_sym)
    aria = label ? %(role="img" aria-label="#{ERB::Util.html_escape(label)}") : 'aria-hidden="true"'
    %(<svg xmlns="http://www.w3.org/2000/svg" width="#{size}" height="#{size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" #{aria}>#{paths}</svg>).html_safe
  end
end
