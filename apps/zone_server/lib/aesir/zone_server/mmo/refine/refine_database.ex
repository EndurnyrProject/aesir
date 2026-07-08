defmodule Aesir.ZoneServer.Mmo.Refine.RefineDatabase do
  @moduledoc """
  Renewal refine tables, loaded as data from `priv/db/refine/refine.yml`.

  Indexes each `(group, item_level, refine_level)` triple to its bonus/rate
  data and resolves ore material aegis names to nameids against
  `Mmo.ItemManagement.Items` at load time. Cached in `:persistent_term`;
  `reload/0` rebuilds it after the data file changes in a long-running
  session - mirrors the cache convention in `Mmo.ItemManagement.Items`.

  **Off-by-one - two consumers, two offsets.** `level_info/3` is keyed by the
  literal yml `RefineLevels.Level` (`1..20`); it applies no offset itself.
  Each consumer applies its own: the equip stat bonus for a `+N` item reads
  `level_info(group, item_level, N)`; the refine process attempting
  `+N -> +N+1` reads `level_info(group, item_level, N + 1)`.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  @pt_key __MODULE__

  @typedoc "Refine table group, derived from item type + weapon/armor level."
  @type group :: :armor | :weapon | :shadow_armor | :shadow_weapon

  @typedoc "Cost type selecting one `Chances` entry."
  @type cost_type :: :normal | :hd | :enriched

  @typedoc "One cost-type entry, with its material resolved to a nameid."
  @type chance :: %{
          rate: non_neg_integer(),
          price: non_neg_integer(),
          material_nameid: integer() | nil,
          breaking_rate: non_neg_integer(),
          downgrade: non_neg_integer()
        }

  @typedoc "Bonus/rate data for one `(group, item_level, refine_level)` triple."
  @type level_info :: %{
          bonus: integer(),
          randombonus_max: integer(),
          blessing_amount: non_neg_integer(),
          broadcast_success: boolean(),
          broadcast_failure: boolean(),
          chances: %{cost_type() => chance()}
        }

  @doc """
  Returns the bonus/rate data for `(group, item_level, yml_level)`, or `nil`
  when the triple is absent from `refine.yml`.

  `yml_level` is the literal yml `RefineLevels.Level` - see the moduledoc for
  which offset each consumer must apply.
  """
  @spec level_info(group(), integer(), integer()) :: level_info() | nil
  def level_info(group, item_level, yml_level) do
    Map.get(index(), {group, item_level, yml_level})
  end

  @doc """
  Rebuilds the cached index after editing `refine.yml` in a running session.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build())
    :ok
  end

  @spec index() :: %{{group(), integer(), integer()} => level_info()}
  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = build()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  @spec build() :: %{{group(), integer(), integer()} => level_info()}
  defp build do
    raw = YamlElixir.read_from_file!(data_file())
    materials = raw |> collect_materials() |> resolve_materials()

    raw
    |> Enum.flat_map(&group_entries(&1, materials))
    |> Map.new()
  end

  @spec collect_materials([map()]) :: [String.t()]
  defp collect_materials(raw) do
    for %{"levels" => levels} <- raw,
        %{"refine_levels" => refine_levels} <- levels,
        %{"chances" => chances} <- refine_levels,
        %{"material" => material} <- chances do
      material
    end
    |> Enum.uniq()
  end

  @spec resolve_materials([String.t()]) :: %{String.t() => integer() | nil}
  defp resolve_materials(names), do: Map.new(names, &{&1, resolve_material(&1)})

  @spec resolve_material(String.t()) :: integer() | nil
  defp resolve_material(aegis) do
    case Items.by_aegis(aegis) do
      {:ok, item} ->
        item.id

      :error ->
        Logger.warning("refine: unresolved material aegis #{inspect(aegis)}; nameid left nil")
        nil
    end
  end

  @spec group_entries(map(), %{String.t() => integer() | nil}) ::
          [{{group(), integer(), integer()}, level_info()}]
  defp group_entries(%{"group" => group_name, "levels" => levels}, materials) do
    group = to_group(group_name)

    for %{"level" => item_level, "refine_levels" => refine_levels} <- levels,
        refine_level <- refine_levels do
      {{group, item_level, refine_level["level"]}, to_level_info(refine_level, materials)}
    end
  end

  @spec to_group(String.t()) :: group()
  defp to_group("armor"), do: :armor
  defp to_group("weapon"), do: :weapon
  defp to_group("shadow_armor"), do: :shadow_armor
  defp to_group("shadow_weapon"), do: :shadow_weapon

  @spec to_level_info(map(), %{String.t() => integer() | nil}) :: level_info()
  defp to_level_info(
         %{
           "bonus" => bonus,
           "random_bonus" => random_bonus,
           "blacksmith_blessing_amount" => blessing_amount,
           "broadcast_success" => broadcast_success,
           "broadcast_failure" => broadcast_failure,
           "chances" => chances
         },
         materials
       ) do
    %{
      bonus: bonus,
      randombonus_max: random_bonus,
      blessing_amount: blessing_amount,
      broadcast_success: broadcast_success,
      broadcast_failure: broadcast_failure,
      chances: Map.new(chances, &to_chance(&1, materials))
    }
  end

  @spec to_chance(map(), %{String.t() => integer() | nil}) :: {cost_type(), chance()}
  defp to_chance(
         %{
           "type" => type,
           "rate" => rate,
           "price" => price,
           "material" => material,
           "breaking_rate" => breaking_rate,
           "downgrade_amount" => downgrade
         },
         materials
       ) do
    {to_cost_type(type),
     %{
       rate: rate,
       price: price,
       material_nameid: Map.fetch!(materials, material),
       breaking_rate: breaking_rate,
       downgrade: downgrade
     }}
  end

  @spec to_cost_type(String.t()) :: cost_type()
  defp to_cost_type("normal"), do: :normal
  defp to_cost_type("hd"), do: :hd
  defp to_cost_type("enriched"), do: :enriched

  @spec data_file() :: Path.t()
  defp data_file, do: Application.app_dir(:zone_server, "priv/db/refine/refine.yml")
end
