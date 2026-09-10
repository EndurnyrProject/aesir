defmodule Aesir.ZoneServer.Mmo.Skill.Audit do
  @moduledoc """
  Pure comparison logic for auditing a skill's static definition against its
  source database row.

  Every function here is a plain data transform: no IO, no catalog or tree
  lookups, no application env or `:persistent_term` reads. The owning Mix
  task resolves the job's skills and reads the source rows, then calls these
  functions per skill.

  ## Per-level expansion

  A source field can be a flat scalar (applies to every level) or a list of
  `%{"Level" => level, <subkey> => value}` entries covering levels up to some
  highest listed level `n`. When the field's comparison horizon (a skill's
  `MaxLevel`) extends past `n`, the missing levels are filled by detecting a
  constant step-wise difference across the listed values (trying step sizes
  `1..div(n, 2)`) and projecting it forward; a filled value that would drop
  below `1` is clamped to `1` and the projection stops advancing further. If
  no step reproduces a constant difference, the missing levels repeat the
  last listed value.

  ## Field comparison

  A field compares as a per-level sequence over the source row's `MaxLevel`:
  the source side is the expansion above, the Aesir side is the definition's
  own value repeated (scalar) or extended past its own length the same way
  (last value, or `Skill.Catalog.sp_cost_at/2`-style extrapolation for
  `sp_cost`; an empty Aesir list, meaning the field was never declared,
  extends as `0`). One finding is produced per field whose sequences
  differ, never per level.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @typedoc "One field mismatch: the current Aesir value and the source-derived correct value."
  @type finding :: %{field: atom(), aesir: term(), source: term()}

  @numeric_fields [
    {["Range"], "Size", :range, false},
    {["HitCount"], "Count", :hit_count, false},
    {["SplashArea"], "Area", :splash_radius, false},
    {["Knockback"], "Amount", :knockback, false},
    {["CastTime"], "Time", :cast_time, false},
    {["FixedCastTime"], "Time", :fixed_cast_time, false},
    {["AfterCastActDelay"], "Time", :after_cast_delay, false},
    {["Cooldown"], "Time", :cooldown, false},
    {["Requires", "SpCost"], "Amount", :sp_cost, true},
    {["Requires", "HpCost"], "Amount", :hp_cost, false},
    {["Requires", "HpRateCost"], "Amount", :hp_cost_rate, false},
    {["Requires", "ZenyCost"], "Amount", :zeny_cost, false},
    {["Requires", "SpiritSphereCost"], "Amount", :sphere_cost, false}
  ]

  @element_overrides %{"Dark" => :shadow}

  @weapon_names %{
    "Fist" => :fist,
    "Dagger" => :dagger,
    "1hSword" => :one_handed_sword,
    "2hSword" => :two_handed_sword,
    "1hSpear" => :one_handed_spear,
    "2hSpear" => :two_handed_spear,
    "1hAxe" => :one_handed_axe,
    "2hAxe" => :two_handed_axe,
    "Mace" => :mace,
    "2hMace" => :two_handed_mace,
    "Staff" => :staff,
    "2hStaff" => :two_handed_staff,
    "Bow" => :bow,
    "Knuckle" => :knuckle,
    "Musical" => :musical,
    "Whip" => :whip,
    "Book" => :book,
    "Katar" => :katar,
    "Revolver" => :revolver,
    "Rifle" => :rifle,
    "Gatling" => :gatling,
    "Shotgun" => :shotgun,
    "Grenade" => :grenade,
    "Huuma" => :huuma,
    "Shield" => :shield
  }

  @doc """
  Expands a source field to one value per level, `1..max_level`.

  `value` is either a flat scalar (applied to every level) or a list of
  `%{"Level" => level, <subkey> => value}` maps. See the moduledoc for the
  expansion rule used past the highest listed level.
  """
  @spec expand_levels(integer() | [map()], String.t(), pos_integer()) :: [integer()]
  def expand_levels(value, _subkey, max_level) when is_integer(value) do
    List.duplicate(value, max_level)
  end

  def expand_levels(entries, subkey, max_level) when is_list(entries) do
    by_level = Map.new(entries, &{Map.fetch!(&1, "Level"), Map.fetch!(&1, subkey)})
    highest = entries |> Enum.map(&Map.fetch!(&1, "Level")) |> Enum.max()

    1..highest
    |> Enum.map(&Map.get(by_level, &1, 0))
    |> extend_to(max_level)
  end

  @doc """
  Compares a skill's Aesir `definition` against its source database `row`.

  Returns one `finding/0` per field whose per-level sequence differs between
  the two, over the source row's `MaxLevel`. `fixed_cast_time` is skipped
  entirely when `mode` is `:pre_renewal` (the field does not exist pre-renewal),
  and `range` is skipped for a self-cast or passive skill, which has no reach to
  declare: Aesir leaves those at `0` whatever the source row happens to carry.
  """
  @spec compare(Definition.t(), map(), Aesir.Commons.GameMode.t()) :: [finding()]
  def compare(%Definition{} = definition, source_row, mode) when is_map(source_row) do
    max_level = Map.fetch!(source_row, "MaxLevel")

    compare_max_level(definition, max_level) ++
      Enum.flat_map(
        numeric_fields(mode),
        &compare_numeric_field(&1, definition, source_row, max_level)
      ) ++
      compare_element(definition, source_row, max_level) ++
      compare_requires_ammo(definition, source_row) ++
      compare_require_weapon(definition, source_row) ++
      compare_vulture_range(definition, source_row) ++
      compare_item_cost(definition, source_row)
  end

  @doc """
  Renders one paste-ready `` ```elixir ``` `` block with a corrected option
  per finding.

  For a field whose `definition` value is mode-keyed (`[renewal: _,
  pre_renewal: _]`), the rendered option stays mode-keyed when the other
  mode's existing value differs from the finding's source value (so fixing
  the current mode does not silently change the other mode); otherwise a
  plain option is rendered.
  """
  @spec suggest(Definition.t(), [finding()], Aesir.Commons.GameMode.t()) :: String.t()
  def suggest(%Definition{} = definition, findings, mode) do
    lines =
      findings
      |> Enum.reject(&(&1.aesir == :unresolved))
      |> Enum.uniq_by(& &1.field)
      |> Enum.map(&render_option(&1, definition, mode))

    "```elixir\n" <> Enum.join(lines, "\n") <> "\n```"
  end

  @spec render_option(finding(), Definition.t(), Aesir.Commons.GameMode.t()) :: String.t()
  defp render_option(%{field: field, source: source}, definition, mode) do
    case mode_keyed_other_value(Map.get(definition, field), mode) do
      {:ok, other_value} when other_value != source ->
        "#{field}: [#{mode}: #{render_value(source)}, #{other_mode(mode)}: #{render_value(other_value)}]"

      _not_diverging ->
        "#{field}: #{render_value(source)}"
    end
  end

  @doc "Renders one value for a report; integer sequences never print as charlists."
  @spec render_value(term()) :: String.t()
  def render_value(value), do: inspect(value, charlists: :as_lists)

  @spec mode_keyed_other_value(term(), Aesir.Commons.GameMode.t()) :: {:ok, term()} | :error
  defp mode_keyed_other_value(value, mode) do
    if Keyword.keyword?(value) and Enum.sort(Keyword.keys(value)) == [:pre_renewal, :renewal] do
      Keyword.fetch(value, other_mode(mode))
    else
      :error
    end
  end

  @doc "The mode not given: `:renewal` for `:pre_renewal` and vice versa."
  @spec other_mode(Aesir.Commons.GameMode.t()) :: Aesir.Commons.GameMode.t()
  def other_mode(:renewal), do: :pre_renewal
  def other_mode(:pre_renewal), do: :renewal

  @spec numeric_fields(Aesir.Commons.GameMode.t()) :: [
          {[String.t()], String.t(), atom(), boolean()}
        ]
  defp numeric_fields(:pre_renewal),
    do: Enum.reject(@numeric_fields, &(elem(&1, 2) == :fixed_cast_time))

  defp numeric_fields(_mode), do: @numeric_fields

  @doc """
  Returns the raw (pre-normalization) `HitCount` values that are negative,
  over `max_level` levels.

  A negative `HitCount` is valid source data (rAthena reads its magnitude
  and treats the sign as its own flag); `compare/3` normalizes it away when
  comparing against Aesir's always-positive `hit_count`, so this is not a
  finding, only something worth calling out in the report.
  """
  @spec negative_hit_count_levels(map(), pos_integer()) :: [integer()]
  def negative_hit_count_levels(source_row, max_level) do
    source_row
    |> fetch_path(["HitCount"], 0)
    |> expand_levels("Count", max_level)
    |> Enum.filter(&(&1 < 0))
  end

  @spec compare_max_level(Definition.t(), integer()) :: [finding()]
  defp compare_max_level(%Definition{max_level: aesir_max}, source_max) do
    if aesir_max == source_max,
      do: [],
      else: [%{field: :max_level, aesir: aesir_max, source: source_max}]
  end

  @spec compare_numeric_field(
          {[String.t()], String.t(), atom(), boolean()},
          Definition.t(),
          map(),
          integer()
        ) ::
          [finding()]
  defp compare_numeric_field(
         {_path, _subkey, :range, _sp_cost?},
         %Definition{target_type: target_type},
         _source_row,
         _max_level
       )
       when target_type in [:self, :passive] do
    []
  end

  defp compare_numeric_field({path, subkey, field, sp_cost?}, definition, source_row, max_level) do
    source_value = fetch_path(source_row, path, 0)

    source_sequence =
      source_value
      |> expand_levels(subkey, max_level)
      |> Enum.map(&normalize_source_value(field, &1))

    aesir_value = Map.fetch!(definition, field)
    aesir_sequence = aesir_numeric_sequence(aesir_value, max_level, sp_cost?)

    if source_sequence == aesir_sequence do
      []
    else
      [%{field: field, aesir: aesir_value, source: source_sequence}]
    end
  end

  # Both fields encode a flag in the sign and the value in the magnitude: a
  # negative `HitCount` is still that many hits, and a negative `Range` is still
  # that many cells (the sign only asks for the weapon's reach on a server
  # configured to use it, which is not the default Aesir follows).
  @spec normalize_source_value(atom(), integer()) :: integer()
  defp normalize_source_value(:hit_count, value), do: max(abs(value), 1)
  defp normalize_source_value(:range, value), do: abs(value)
  defp normalize_source_value(_field, value), do: value

  @spec aesir_numeric_sequence(integer() | [integer() | :all], pos_integer(), boolean()) :: [
          integer()
        ]
  defp aesir_numeric_sequence(value, max_level, _sp_cost?) when is_integer(value) do
    List.duplicate(value, max_level)
  end

  defp aesir_numeric_sequence(value, max_level, sp_cost?) when is_list(value) do
    Enum.map(1..max_level, fn level ->
      case Enum.fetch(value, level - 1) do
        {:ok, entry} -> entry
        :error -> beyond_list_value(value, level, sp_cost?)
      end
    end)
  end

  @spec beyond_list_value([integer() | :all], pos_integer(), boolean()) :: integer()
  defp beyond_list_value(value, level, true), do: Catalog.sp_cost_at(value, level)
  defp beyond_list_value(value, _level, false), do: List.last(value, 0)

  @spec compare_element(Definition.t(), map(), pos_integer()) :: [finding()]
  defp compare_element(
         %Definition{element: aesir_element, damage_kind: damage_kind},
         source_row,
         max_level
       ) do
    source_sequence =
      source_row |> Map.get("Element", "Neutral") |> expand_element_levels(max_level)

    if Enum.all?(source_sequence, &element_equal?(&1, aesir_element, damage_kind)) do
      []
    else
      [%{field: :element, aesir: aesir_element, source: source_sequence}]
    end
  end

  # A weapon-kind skill's damage always carries the wielded weapon's element;
  # a source `Weapon` element and Aesir's `:neutral` default both mean that,
  # so they compare equal only for that damage kind.
  @spec element_equal?(atom(), atom(), Definition.damage_kind()) :: boolean()
  defp element_equal?(:weapon, :neutral, :weapon), do: true

  defp element_equal?(source_element, aesir_element, _damage_kind),
    do: source_element == aesir_element

  @spec expand_element_levels(String.t() | [map()], pos_integer()) :: [atom()]
  defp expand_element_levels(value, max_level) when is_binary(value) do
    List.duplicate(element_atom(value), max_level)
  end

  defp expand_element_levels(entries, max_level) when is_list(entries) do
    entries
    |> Enum.sort_by(&Map.fetch!(&1, "Level"))
    |> Enum.map(&(Map.fetch!(&1, "Element") |> element_atom()))
    |> extend_last(max_level)
  end

  # rAthena source data; the element name set is closed and this is not a security boundary.
  # sobelow_skip ["DOS.StringToAtom"]
  @spec element_atom(String.t()) :: atom()
  defp element_atom(name) do
    Map.get_lazy(@element_overrides, name, fn -> name |> String.downcase() |> String.to_atom() end)
  end

  @spec compare_requires_ammo(Definition.t(), map()) :: [finding()]
  defp compare_requires_ammo(%Definition{requires_ammo: aesir_flag}, source_row) do
    source_flag =
      source_row |> fetch_path(["Requires", "Ammo"], %{}) |> Map.values() |> Enum.any?(& &1)

    if source_flag == aesir_flag,
      do: [],
      else: [%{field: :requires_ammo, aesir: aesir_flag, source: source_flag}]
  end

  @spec compare_require_weapon(Definition.t(), map()) :: [finding()]
  defp compare_require_weapon(%Definition{require_weapon: aesir_weapons}, source_row) do
    source_weapons =
      source_row
      |> fetch_path(["Requires", "Weapon"], %{})
      |> Enum.filter(fn {_name, required?} -> required? end)
      |> Enum.map(fn {name, _required?} -> Map.fetch!(@weapon_names, name) end)
      |> Enum.sort()

    aesir_sorted = Enum.sort(aesir_weapons)

    if source_weapons == aesir_sorted do
      []
    else
      [%{field: :require_weapon, aesir: aesir_weapons, source: source_weapons}]
    end
  end

  # The source marks a skill whose range trains with Vulture's Eye by a flag on
  # the row; Aesir declares the same thing as a boolean definition field.
  @spec compare_vulture_range(Definition.t(), map()) :: [finding()]
  defp compare_vulture_range(%Definition{vulture_range: aesir_flag}, source_row) do
    source_flag =
      source_row |> fetch_path(["Flags", "AlterRangeVulture"], false) |> then(&(&1 == true))

    if source_flag == aesir_flag,
      do: [],
      else: [%{field: :vulture_range, aesir: aesir_flag, source: source_flag}]
  end

  @spec compare_item_cost(Definition.t(), map()) :: [finding()]
  defp compare_item_cost(%Definition{item_cost: aesir_cost}, source_row) do
    raw = fetch_path(source_row, ["Requires", "ItemCost"], [])
    {resolved, unresolved} = resolve_item_cost(raw)

    unresolved_findings =
      Enum.map(unresolved, fn aegis -> %{field: :item_cost, aesir: :unresolved, source: aegis} end)

    if Enum.sort(resolved) == Enum.sort(aesir_cost) do
      unresolved_findings
    else
      [%{field: :item_cost, aesir: aesir_cost, source: resolved} | unresolved_findings]
    end
  end

  @spec resolve_item_cost([map()]) :: {[Definition.item_cost_entry()], [String.t()]}
  defp resolve_item_cost(raw) do
    Enum.reduce(raw, {[], []}, fn %{"Item" => aegis, "Amount" => amount},
                                  {resolved, unresolved} ->
      case Items.by_aegis(aegis) do
        {:ok, %{id: id}} -> {[%{id: id, amount: amount} | resolved], unresolved}
        :error -> {resolved, [aegis | unresolved]}
      end
    end)
  end

  @spec fetch_path(map(), [String.t()], term()) :: term()
  defp fetch_path(row, path, default) do
    Enum.reduce(path, row, fn key, acc ->
      if is_map(acc), do: Map.get(acc, key, default), else: default
    end)
  end

  @spec extend_to([integer()], pos_integer()) :: [integer()]
  defp extend_to(values, max_level) do
    n = length(values)

    cond do
      max_level <= n ->
        Enum.take(values, max_level)

      step_trend = find_step(values, n) ->
        {step, diff} = step_trend
        fill_with_step(values, n, max_level, step, diff)

      true ->
        extend_last(values, max_level)
    end
  end

  @spec extend_last([term()], pos_integer()) :: [term()]
  defp extend_last(values, max_level) do
    n = length(values)

    if max_level <= n,
      do: Enum.take(values, max_level),
      else: values ++ List.duplicate(List.last(values), max_level - n)
  end

  @spec find_step([integer()], pos_integer()) :: {pos_integer(), integer()} | nil
  defp find_step(values, n) do
    Enum.find_value(1..div(n, 2)//1, fn step ->
      diff = Enum.at(values, n - 1) - Enum.at(values, n - step - 1)
      if trend_holds?(values, n, step, diff), do: {step, diff}
    end)
  end

  @spec trend_holds?([integer()], pos_integer(), pos_integer(), integer()) :: boolean()
  defp trend_holds?(values, n, step, diff) do
    Enum.all?(step..(n - 1), fn j -> Enum.at(values, j) - Enum.at(values, j - step) == diff end)
  end

  @spec fill_with_step([integer()], pos_integer(), pos_integer(), pos_integer(), integer()) :: [
          integer()
        ]
  defp fill_with_step(values, n, max_level, step, diff) do
    {result, _capped?} =
      Enum.reduce(n..(max_level - 1), {values, false}, &step_fill(&1, &2, step, diff))

    result
  end

  @spec step_fill(non_neg_integer(), {[integer()], boolean()}, pos_integer(), integer()) ::
          {[integer()], boolean()}
  defp step_fill(_i, {acc, true}, _step, _diff), do: {acc ++ [1], true}

  defp step_fill(i, {acc, false}, step, diff) do
    prev = Enum.at(acc, i - step)
    candidate = prev + diff

    if candidate < 1 and prev >= 0 do
      {acc ++ [1], true}
    else
      {acc ++ [candidate], false}
    end
  end
end
