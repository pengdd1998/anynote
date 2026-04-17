package platform

import "fmt"

// Registry manages platform adapters.
type Registry struct {
	adapters map[string]Adapter
}

// NewRegistry creates a new adapter registry.
func NewRegistry() *Registry {
	return &Registry{
		adapters: make(map[string]Adapter),
	}
}

// Register adds a platform adapter.
func (r *Registry) Register(name string, adapter Adapter) {
	r.adapters[name] = adapter
}

// Get retrieves a platform adapter by name.
func (r *Registry) Get(name string) (Adapter, error) {
	a, ok := r.adapters[name]
	if !ok {
		return nil, fmt.Errorf("unsupported platform: %s", name)
	}
	return a, nil
}

// List returns all registered platform names.
func (r *Registry) List() []string {
	names := make([]string, 0, len(r.adapters))
	for name := range r.adapters {
		names = append(names, name)
	}
	return names
}
