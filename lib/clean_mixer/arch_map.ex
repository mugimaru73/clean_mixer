defmodule CleanMixer.ArchMap do
  alias CleanMixer.ArchMap.Component
  alias CleanMixer.ArchMap.Dependency
  alias CleanMixer.CodeMap.SourceFile
  alias CleanMixer.Graph

  defstruct components: [],
            dependencies: []

  @type t :: %__MODULE__{
          components: list(Component.t()),
          dependencies: list(Dependency.t())
        }

  defimpl Inspect do
    def inspect(arch_map, opts) do
      Inspect.Any.inspect(arch_map, %Inspect.Opts{opts | limit: 1})
    end
  end

  @spec new(list(Component.t()), list(Dependency.t())) :: t
  def new(components, dependencies) do
    %__MODULE__{
      components: components,
      dependencies: dependencies
    }
  end

  @spec build(list(Component.t())) :: t
  def build(components) do
    new(components, build_dependencies(components))
  end

  @spec component(t, Component.name()) :: Component.t() | nil
  def component(arch_map, name) do
    arch_map.components |> Enum.find(&(&1.name == name))
  end

  @spec component_with_file(t, Path.t()) :: Component.t() | nil
  def component_with_file(arch_map, path) do
    arch_map.components |> Enum.find(&Component.has_file?(&1, path))
  end

  @spec dependencies_of(t, Component.t()) :: list(Dependency.t())
  def dependencies_of(%__MODULE__{dependencies: deps}, %Component{} = component) do
    Enum.filter(deps, &(&1.source == component))
  end

  @spec usages_of(t, Component.t()) :: list(Dependency.t())
  def usages_of(%__MODULE__{dependencies: deps}, %Component{} = component) do
    Enum.filter(deps, &(&1.target == component))
  end

  @spec public_files(t, Component.t()) :: list(SourceFile.t())
  def public_files(%__MODULE__{} = arch_map, %Component{} = component) do
    arch_map
    |> usages_of(component)
    |> Enum.flat_map(& &1.files)
    |> Enum.map(& &1.target)
    |> Enum.uniq()
  end

  @spec except(t, list(Component.t())) :: t
  def except(arch_map, components) do
    filtered_componens = arch_map.components -- components
    build(filtered_componens)
  end

  @spec graph(t()) :: Graph.t()
  def graph(arch_map) do
    graph = :digraph.new()

    Enum.each(arch_map.components, &:digraph.add_vertex(graph, &1))
    Enum.each(arch_map.dependencies, &:digraph.add_edge(graph, &1.source, &1.target))

    graph
  end

  defp build_dependencies(components) do
    components
    |> Enum.flat_map(&build_deps_for(&1, components))
    |> Enum.uniq()
  end

  defp build_deps_for(component, all_components) do
    other_components =
      (all_components -- [component])
      |> Enum.reject(&Component.child?(&1, component))
      |> sort_by_deps()

    build_deps_for(component, other_components, [])
  end

  defp sort_by_deps(components) do
    components
    |> Enum.sort_by(&Component.depth/1)
    |> Enum.reverse()
  end

  defp build_deps_for(_component, [] = _other_components, resulting_dependencies) do
    Enum.reverse(resulting_dependencies)
  end

  defp build_deps_for(component, [other_comp | rest_components], deps_so_far) do
    file_deps = Component.file_dependencies(component, other_comp) -- file_deps_of(deps_so_far)

    case file_deps do
      [] ->
        build_deps_for(component, rest_components, deps_so_far)

      [_ | _] ->
        new_dep = Dependency.new(component, other_comp, file_deps)
        build_deps_for(component, rest_components, [new_dep | deps_so_far])
    end
  end

  defp file_deps_of(component_deps) do
    Enum.flat_map(component_deps, & &1.files)
  end
end
