defmodule Aesir.ZoneServer.Mmo.ItemManagement.Loader do
  @moduledoc """
  Builds the item index from our-schema YAML files in the items domain.

  Parses every source into `ItemDefinition` structs and indexes
  them by id and aegis name. Cache mechanics live in `Aesir.ZoneServer.Mmo.DataLoader`.
  Plain functions only - no process.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement.ItemEligibility

  @type index :: %{
          all: [ItemDefinition.t()],
          by_id: %{integer() => ItemDefinition.t()},
          by_aegis: %{String.t() => ItemDefinition.t()}
        }

  @cache_file "items_v7.etf"
  @overrides_file "script_overrides.yml"

  @types ~w(healing usable etc armor weapon card pet_egg pet_armor ammo delay_consume shadow_gear cash)a
  @subtypes ~w(one_handed_sword two_handed_sword one_handed_spear two_handed_spear one_handed_axe two_handed_axe two_handed_staff dagger mace staff bow knuckle musical whip book katar revolver rifle gatling shotgun grenade huuma arrow bullet cannonball kunai shuriken throw_weapon enchant)a
  @attack_elements ~w(fire water wind earth holy shadow ghost poison undead neutral)a
  @classes ~w(normal upper baby third third_upper third_baby fourth)a
  @genders ~w(both male female)a
  @locations ~w(head_low right_hand garment right_accessory armor left_hand shoes left_accessory head_top head_mid costume_head_top costume_head_mid costume_head_low costume_garment ammo shadow_armor shadow_weapon shadow_shield shadow_shoes shadow_right_accessory shadow_left_accessory both_hand both_accessory)a

  @type_tokens Map.new(@types, &{Atom.to_string(&1), &1})
  @subtype_tokens Map.new(@subtypes, &{Atom.to_string(&1), &1})
  @attack_element_tokens Map.new(@attack_elements, &{Atom.to_string(&1), &1})
  @job_tokens Map.new(ItemEligibility.families(), &{Atom.to_string(&1), &1})
  @class_tokens Map.new(@classes, &{Atom.to_string(&1), &1})
  @gender_tokens Map.new(@genders, &{Atom.to_string(&1), &1})
  @location_tokens Map.new(@locations, &{Atom.to_string(&1), &1})

  # Valid YAML keys -> struct field atoms. Sourced from the struct so the atoms
  # are guaranteed to exist regardless of load order, and unknown keys raise.
  @field_names ItemDefinition
               |> struct(%{})
               |> Map.from_struct()
               |> Map.keys()
               |> Map.new(&{Atom.to_string(&1), &1})

  @spec load() :: index()
  def load, do: "items" |> DataLoader.load(@cache_file, &build/1) |> index()

  @spec build([Path.t()]) :: [ItemDefinition.t()]
  defp build(sources) do
    {override_sources, def_sources} =
      Enum.split_with(sources, &(Path.basename(&1) == @overrides_file))

    overrides = parse_overrides(override_sources)

    def_sources
    |> Enum.flat_map(fn source ->
      source
      |> DataLoader.parse_file()
      |> Enum.map(&to_struct!(&1, source))
      |> Enum.map(&apply_override(&1, overrides, source))
    end)
    |> DataLoader.merge_by_key(& &1.id)
  end

  @spec parse_overrides([Path.t()]) :: %{integer() => String.t()}
  defp parse_overrides(sources) do
    sources
    |> Enum.flat_map(&DataLoader.parse_file/1)
    |> Map.new(fn %{"id" => id, "on_use" => on_use} -> {id, on_use} end)
  end

  @spec apply_override(ItemDefinition.t(), %{integer() => String.t()}, Path.t()) ::
          ItemDefinition.t()
  defp apply_override(definition, overrides, source) do
    if Path.dirname(source) == Source.base_dir("items") do
      case Map.fetch(overrides, definition.id) do
        {:ok, on_use} -> %{definition | on_use: on_use}
        :error -> definition
      end
    else
      definition
    end
  end

  @spec index([ItemDefinition.t()]) :: index()
  defp index(defs) do
    %{
      all: defs,
      by_id: Map.new(defs, &{&1.id, &1}),
      by_aegis: Map.new(defs, &{&1.aegis_name, &1})
    }
  end

  @spec to_struct!(map(), Path.t()) :: ItemDefinition.t()
  defp to_struct!(yaml_map, source) do
    attrs =
      Map.new(yaml_map, fn {k, v} ->
        key = Map.fetch!(@field_names, k)
        {key, convert(key, v, source)}
      end)
      |> Map.put_new(:jobs, :all)
      |> Map.put_new(:classes, ItemDefinition.default_classes(ItemEligibility.mode()))
      |> Map.put_new(:gender, :both)

    ItemDefinition
    |> struct!(attrs)
    |> ItemDefinition.normalize_gender()
  rescue
    error in KeyError ->
      reraise %KeyError{
                error
                | message:
                    (error.message || "key #{inspect(error.key)} not found") <> " (in #{source})"
              },
              __STACKTRACE__
  end

  defp convert(:type, value, source), do: decode_token!(:type, value, @type_tokens, source)

  defp convert(:subtype, nil, _source), do: nil

  defp convert(:subtype, value, source),
    do: decode_token!(:subtype, value, @subtype_tokens, source)

  defp convert(:attack_element, nil, _source), do: nil

  defp convert(:attack_element, value, source),
    do: decode_token!(:attack_element, value, @attack_element_tokens, source)

  defp convert(:jobs, "all", _source), do: :all
  defp convert(:jobs, value, source), do: decode_list!(:jobs, value, @job_tokens, source)
  defp convert(:classes, value, source), do: decode_list!(:classes, value, @class_tokens, source)
  defp convert(:gender, value, source), do: decode_token!(:gender, value, @gender_tokens, source)

  defp convert(:locations, value, source),
    do: decode_list!(:locations, value, @location_tokens, source)

  defp convert(key, value, _source) when key in [:on_equip, :on_unequip],
    do: EquipScript.parse!(value)

  defp convert(_key, value, _source), do: value

  defp decode_list!(field, values, tokens, source) when is_list(values),
    do: Enum.map(values, &decode_token!(field, &1, tokens, source))

  defp decode_list!(field, value, _tokens, source),
    do: invalid_token!(field, value, source)

  defp decode_token!(field, value, tokens, source) when is_binary(value) do
    case Map.fetch(tokens, value) do
      {:ok, token} -> token
      :error -> invalid_token!(field, value, source)
    end
  end

  defp decode_token!(field, value, _tokens, source), do: invalid_token!(field, value, source)

  defp invalid_token!(field, value, source) do
    raise ArgumentError, "unknown #{field} token #{inspect(value)} (in #{source})"
  end
end
