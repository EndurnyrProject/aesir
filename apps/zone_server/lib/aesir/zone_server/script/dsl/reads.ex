defmodule Aesir.ZoneServer.Script.Dsl.Reads do
  @moduledoc """
  Pure-read buildins for the script DSL: player identity/progression/vitals,
  job lineage and class mapping, mount/cart/falcon checks, equipment and
  refine inspection, item info, party leadership, NPC identity, time ticks,
  and string formatting helpers.

  Reads return bare values (not a `Ctx`), so a detached ctx raises
  `ArgumentError` via `no_player!/1` instead of halting — except the reads
  that document a detached default. Imported into scripts via the
  `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Bitwise

  import Aesir.ZoneServer.Script.Dsl.Internal,
    only: [no_player!: 1]

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.JobManagement.JobMapid
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl.Internal
  alias Aesir.ZoneServer.Script.Rathena
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Whether the attached player has a Falcon: `1` when the Falcon option bit is
  set, otherwise `0`. Detached contexts report `0`.
  """
  @spec checkfalcon(Ctx.t()) :: 0 | 1
  def checkfalcon(%Ctx{game_state: nil}), do: 0

  def checkfalcon(%Ctx{game_state: gs}) do
    if (gs.option &&& Option.id(:falcon)) != 0, do: 1, else: 0
  end

  @doc """
  Whether the attached player is mounted (rAthena `ismounting`): `1` when the
  riding option bit is set, else `0`. Aesir models only the Peco-Peco mount
  (`set_riding/2`) and has no separate cash-mount concept, so this reads the
  riding bit. Detached contexts report `0`.
  """
  @spec ismounting(Ctx.t()) :: 0 | 1
  def ismounting(%Ctx{game_state: nil}), do: 0

  def ismounting(%Ctx{game_state: gs}) do
    if (gs.option &&& Option.id(:riding)) != 0, do: 1, else: 0
  end

  @doc """
  Whether the player has a cart mounted (rAthena `checkcart`): `1` when
  `cart_type` is set, else `0`. Pure read over the ctx snapshot.
  """
  @spec checkcart(Ctx.t()) :: 0 | 1
  def checkcart(%Ctx{game_state: nil}), do: no_player!("checkcart/1")
  def checkcart(%Ctx{game_state: gs}), do: if(gs.cart_type > 0, do: 1, else: 0)

  @doc "The player's base level."
  @spec base_level(Ctx.t()) :: non_neg_integer()
  def base_level(%Ctx{game_state: nil}), do: no_player!("base_level/1")
  def base_level(%Ctx{game_state: gs}), do: gs.stats.progression.base_level

  @doc "The player's job level."
  @spec job_level(Ctx.t()) :: non_neg_integer()
  def job_level(%Ctx{game_state: nil}), do: no_player!("job_level/1")
  def job_level(%Ctx{game_state: gs}), do: gs.stats.progression.job_level

  @doc "The player's job as an atom."
  @spec class(Ctx.t()) :: atom()
  def class(%Ctx{game_state: nil}), do: no_player!("class/1")

  def class(%Ctx{game_state: gs}) do
    {:ok, job} = JobManagement.get_job_by_id(gs.stats.progression.job_id)
    job.name
  end

  @doc """
  The player's first-job lineage root as an atom (rAthena `BaseClass`): a
  Hunter reads `:archer`, a Knight `:swordman`, Novices and Super Novices
  `:novice`.
  """
  @spec base_class(Ctx.t()) :: atom()
  def base_class(%Ctx{game_state: nil}), do: no_player!("base_class/1")
  def base_class(%Ctx{} = ctx), do: ctx |> class() |> JobLineage.base_class()

  @doc """
  The player's job ignoring transcendence and baby variants as an atom
  (rAthena `BaseJob`): a Hunter or Sniper reads `:hunter`, a plain Novice
  `:novice`.
  """
  @spec base_job(Ctx.t()) :: atom()
  def base_job(%Ctx{game_state: nil}), do: no_player!("base_job/1")
  def base_job(%Ctx{} = ctx), do: ctx |> class() |> JobLineage.base_job()

  # NV_BASIC level a Novice must reach to change into a first job.
  @basic_skill_job_req 9

  @doc """
  Whether the player meets the Basic Skill requirement to change job — a learned
  `NV_BASIC` at level #{@basic_skill_job_req} (rAthena `F_CanChangeJob`).
  """
  @spec can_change_job?(Ctx.t()) :: boolean()
  def can_change_job?(%Ctx{game_state: nil}), do: no_player!("can_change_job?/1")

  def can_change_job?(%Ctx{game_state: gs}) do
    case Catalog.by_name(:nv_basic) do
      {:ok, %{id: id}} ->
        Learned.learned_level(gs.stats.progression.learned_skills, id) >= @basic_skill_job_req

      :error ->
        false
    end
  end

  @doc """
  The player's learned level of a skill (rAthena `getskilllv`), `0` when not
  learned. `skill` is a skill id or its catalog name atom; an unknown skill
  returns `0`, matching rAthena's unknown-skill result. Pure read over the
  ctx snapshot.
  """
  @spec getskilllv(Ctx.t(), integer() | atom()) :: non_neg_integer()
  def getskilllv(%Ctx{game_state: nil}, _skill), do: no_player!("getskilllv/2")

  def getskilllv(%Ctx{game_state: gs}, skill), do: Internal.learned_level(gs, skill)

  @doc "`strcharinfo(type)` for the attached character (see `Rathena.strcharinfo/2`)."
  @spec char_name(Ctx.t(), integer()) :: String.t()
  def char_name(%Ctx{game_state: nil}, _type), do: no_player!("char_name/2")
  def char_name(%Ctx{game_state: game_state}, type), do: Rathena.strcharinfo(game_state, type)

  @doc "`strcharinfo(type, char_id)`: the same read for any online character, `\"\"` when offline."
  @spec char_name(Ctx.t(), integer(), integer()) :: String.t()
  def char_name(%Ctx{char_id: char_id} = ctx, type, char_id), do: char_name(ctx, type)

  def char_name(%Ctx{}, type, char_id) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, game_state, _pid}} -> Rathena.strcharinfo(game_state, type)
      {:error, :not_found} -> ""
    end
  end

  @doc "The display name of a job, given its class atom or id (rAthena `jobname`)."
  @spec job_name(Ctx.t(), atom() | integer()) :: String.t()
  def job_name(%Ctx{}, job) when is_atom(job), do: humanize_job(job)

  def job_name(%Ctx{}, job_id) when is_integer(job_id) do
    case JobManagement.get_job_by_id(job_id) do
      {:ok, job} -> humanize_job(job.name)
      {:error, _} -> ""
    end
  end

  defp humanize_job(name) do
    name |> to_string() |> String.split("_") |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  The "eA job number" (mapid) for the attached player's class, or for an
  explicit job atom/id when one is given (rAthena `eaclass`). Returns `-1` for
  an unknown job or a detached context with no class to read.
  """
  @spec eaclass(Ctx.t()) :: integer()
  def eaclass(%Ctx{game_state: nil}), do: -1
  def eaclass(%Ctx{game_state: gs}), do: JobMapid.from_job(gs.stats.progression.job_id)

  @spec eaclass(Ctx.t(), atom() | integer()) :: integer()
  def eaclass(%Ctx{}, job), do: JobMapid.from_job(job)

  @doc """
  The numeric job id for a mapid, resolved against the attached player's sex
  (or male when detached), or against an explicit `sex` (rAthena `roclass`).
  Returns `-1` for an unknown mapid.
  """
  @spec roclass(Ctx.t(), integer()) :: integer()
  def roclass(%Ctx{game_state: nil}, mapid), do: JobMapid.to_job(mapid, 1)
  def roclass(%Ctx{game_state: %{sex: "M"}}, mapid), do: JobMapid.to_job(mapid, 1)
  def roclass(%Ctx{game_state: %{}}, mapid), do: JobMapid.to_job(mapid, 0)

  @spec roclass(Ctx.t(), integer(), integer()) :: integer()
  def roclass(%Ctx{}, mapid, sex), do: JobMapid.to_job(mapid, sex)

  @doc "The player's sex as rAthena's `Sex`: `1` male, `0` female."
  @spec sex(Ctx.t()) :: 0 | 1
  def sex(%Ctx{game_state: nil}), do: no_player!("sex/1")
  def sex(%Ctx{game_state: %{sex: "M"}}), do: 1
  def sex(%Ctx{game_state: %{}}), do: 0

  @doc "The player's current HP."
  @spec hp(Ctx.t()) :: non_neg_integer()
  def hp(%Ctx{game_state: nil}), do: no_player!("hp/1")
  def hp(%Ctx{game_state: gs}), do: gs.stats.current_state.hp

  @doc "The player's current SP."
  @spec sp(Ctx.t()) :: non_neg_integer()
  def sp(%Ctx{game_state: nil}), do: no_player!("sp/1")
  def sp(%Ctx{game_state: gs}), do: gs.stats.current_state.sp

  @doc "The player's maximum HP."
  @spec max_hp(Ctx.t()) :: non_neg_integer()
  def max_hp(%Ctx{game_state: nil}), do: no_player!("max_hp/1")
  def max_hp(%Ctx{game_state: gs}), do: gs.stats.derived_stats.max_hp

  @doc "The player's current carried weight."
  @spec weight(Ctx.t()) :: non_neg_integer()
  def weight(%Ctx{game_state: nil}), do: no_player!("weight/1")
  def weight(%Ctx{game_state: gs}), do: Weight.current_weight(gs.inventory)

  @doc "The player's position as `{x, y, map_name}`."
  @spec position(Ctx.t()) :: {integer(), integer(), String.t()}
  def position(%Ctx{game_state: nil}), do: no_player!("position/1")
  def position(%Ctx{game_state: gs}), do: {gs.x, gs.y, gs.map_name}

  @doc """
  Whether the player has an item with `item_id` equipped, as rAthena's
  `isequipped`: `1` when equipped, `0` otherwise (so transpiled `== 1`/`> 0`
  comparisons work).
  """
  @spec is_equipped(Ctx.t(), integer()) :: 0 | 1
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_equipped(%Ctx{game_state: nil}, _item_id), do: no_player!("is_equipped/2")

  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_equipped(%Ctx{game_state: gs}, item_id) do
    equipped? =
      gs.inventory
      |> Inventory.equipped_items()
      |> Enum.any?(fn {_index, %InventoryItem{nameid: nameid}} -> nameid == item_id end)

    if equipped?, do: 1, else: 0
  end

  @doc """
  The item id worn in equip slot `slot` (rAthena `getequipid`), or `-1` when
  the slot is empty or `slot` is not a known `EQI_*` index. `slot` is the
  rAthena `equip_index` ordinal. Pure read over the inventory snapshot.
  """
  @spec getequipid(Ctx.t(), integer()) :: integer()
  def getequipid(%Ctx{game_state: nil}, _slot), do: no_player!("getequipid/2")

  def getequipid(%Ctx{game_state: gs}, slot) do
    with location when not is_nil(location) <- Internal.equip_slot_location(slot),
         %InventoryItem{nameid: nameid} <- Internal.equipped_in_slot(gs.inventory, location) do
      nameid
    else
      _ -> -1
    end
  end

  @doc """
  The value stored in card slot `card_slot` (`0..3`) of the item worn in equip
  slot `equip_slot` (rAthena `getequipcardid`). Returns `0` when the equipment
  slot is empty or unknown, or when the card slot is outside `0..3`.
  """
  @spec getequipcardid(Ctx.t(), integer(), integer()) :: integer()
  def getequipcardid(%Ctx{game_state: nil}, _equip_slot, _card_slot),
    do: no_player!("getequipcardid/3")

  def getequipcardid(%Ctx{}, _equip_slot, card_slot) when card_slot not in 0..3, do: 0

  def getequipcardid(%Ctx{game_state: gs}, equip_slot, card_slot) do
    with location when not is_nil(location) <- Internal.equip_slot_location(equip_slot),
         %InventoryItem{} = item <- Internal.equipped_in_slot(gs.inventory, location) do
      item |> InventoryItem.cards() |> Enum.at(card_slot)
    else
      _ -> 0
    end
  end

  @doc """
  Whether the equip `slot` is occupied (rAthena `getequipisequiped`): `1` when
  an item is worn there, else `0`. `slot` is the rAthena `equip_index` ordinal.
  Pure read over the inventory snapshot.
  """
  @spec getequipisequiped(Ctx.t(), integer()) :: 0 | 1
  def getequipisequiped(%Ctx{game_state: nil}, _slot), do: no_player!("getequipisequiped/2")

  def getequipisequiped(%Ctx{} = ctx, slot) do
    if Internal.fetch_equipped(ctx, slot), do: 1, else: 0
  end

  @doc """
  The refine level of the item worn in equip `slot` (rAthena
  `getequiprefinerycnt`), or `0` when the slot is empty or unknown. Pure read
  over the inventory snapshot.
  """
  @spec getequiprefinerycnt(Ctx.t(), integer()) :: non_neg_integer()
  def getequiprefinerycnt(%Ctx{game_state: nil}, _slot), do: no_player!("getequiprefinerycnt/2")

  def getequiprefinerycnt(%Ctx{} = ctx, slot) do
    case Internal.fetch_equipped(ctx, slot) do
      {item, _item_def} -> item.refine
      nil -> 0
    end
  end

  @doc """
  The display name of the item worn in equip `slot` (rAthena `getequipname`),
  or `""` when the slot is empty or unknown. Uses the same `name` field as
  `getitemname` for consistency with dialog display. Pure read over the
  inventory snapshot.
  """
  @spec getequipname(Ctx.t(), integer()) :: String.t()
  def getequipname(%Ctx{game_state: nil}, _slot), do: no_player!("getequipname/2")

  def getequipname(%Ctx{} = ctx, slot) do
    case Internal.fetch_equipped(ctx, slot) do
      {_item, %ItemDefinition{name: name}} -> name
      nil -> ""
    end
  end

  @doc """
  The display name of an equip slot, given its rAthena `equip_index` ordinal
  (`F_getpositionname`): `0` → "Accessory 1", … Unknown indices read "Unknown".
  Pure, needs no player state.
  """
  @equip_position_names %{
    0 => "Accessory 1",
    1 => "Accessory 2",
    2 => "Shoes",
    3 => "Robe",
    4 => "Head 3",
    5 => "Head 2",
    6 => "Head",
    7 => "Body",
    8 => "Left hand",
    9 => "Right hand",
    10 => "Upper Costume Headgear",
    11 => "Middle Costume Headgear",
    12 => "Lower Costume Headgear",
    13 => "Costume Garment",
    14 => "Arrow/Ammunition",
    15 => "Shadow Armor",
    16 => "Shadow Weapon",
    17 => "Shadow Shield",
    18 => "Shadow Shoes",
    19 => "Shadow Accessory 2",
    20 => "Shadow Accessory 1"
  }

  @spec equip_position_name(Ctx.t(), integer()) :: String.t()
  def equip_position_name(%Ctx{}, index), do: Map.get(@equip_position_names, index, "Unknown")

  @doc """
  The weapon level of the item worn in equip `slot` (rAthena
  `getequipweaponlv`), or `0` when the slot is empty, unknown, or the worn
  item is not a weapon. Pure read over the inventory snapshot.
  """
  @spec getequipweaponlv(Ctx.t(), integer()) :: non_neg_integer()
  def getequipweaponlv(%Ctx{game_state: nil}, _slot), do: no_player!("getequipweaponlv/2")

  def getequipweaponlv(%Ctx{} = ctx, slot) do
    case Internal.fetch_equipped(ctx, slot) do
      {_item, %ItemDefinition{type: :weapon, weapon_level: level}} when is_integer(level) -> level
      _ -> 0
    end
  end

  @doc """
  The armor level of the item worn in equip `slot` (rAthena
  `getequiparmorlv`), or `0` when the slot is empty, unknown, or the worn
  item is not an armor. Pure read over the inventory snapshot.
  """
  @spec getequiparmorlv(Ctx.t(), integer()) :: non_neg_integer()
  def getequiparmorlv(%Ctx{game_state: nil}, _slot), do: no_player!("getequiparmorlv/2")

  def getequiparmorlv(%Ctx{} = ctx, slot) do
    case Internal.fetch_equipped(ctx, slot) do
      {_item, %ItemDefinition{type: :armor, armor_level: level}} when is_integer(level) -> level
      _ -> 0
    end
  end

  @doc """
  Whether the item worn in equip `slot` can be refined (rAthena
  `getequipisenableref`): `1` when it is a refinable item and not rented,
  else `0`. Pure read over the inventory snapshot.
  """
  @spec getequipisenableref(Ctx.t(), integer()) :: 0 | 1
  def getequipisenableref(%Ctx{game_state: nil}, _slot), do: no_player!("getequipisenableref/2")

  def getequipisenableref(%Ctx{} = ctx, slot) do
    case Internal.fetch_equipped(ctx, slot) do
      {%InventoryItem{expire_time: nil}, %ItemDefinition{refineable: true}} -> 1
      _ -> 0
    end
  end

  @doc """
  The success rate, as a `0..100` percent, of the next refine attempt on the
  item worn in equip `slot` (rAthena `getequippercentrefinery`): normal by
  default, or enriched when `enriched != 0`. `0` when the slot is empty,
  unknown, or the item is not currently refinable at its level. Pure read over
  the inventory snapshot + refine tables.
  """
  @spec getequippercentrefinery(Ctx.t(), integer(), 0 | 1) :: 0..100
  def getequippercentrefinery(ctx, slot, enriched \\ 0)

  def getequippercentrefinery(%Ctx{game_state: nil}, _slot, _enriched),
    do: no_player!("getequippercentrefinery/3")

  def getequippercentrefinery(%Ctx{} = ctx, slot, enriched) do
    cost_type = if enriched != 0, do: :enriched, else: :normal

    with {item, item_def} <- Internal.fetch_equipped(ctx, slot),
         {:ok, group, item_level} <- RefineDatabase.group_and_level(item_def),
         %{chances: chances} <- RefineDatabase.level_info(group, item_level, item.refine + 1),
         %{rate: rate} <- Map.get(chances, cost_type) do
      div(rate, 100)
    else
      _ -> 0
    end
  end

  @doc """
  A refine cost field of the item worn in equip `slot` (rAthena
  `getequiprefinecost`): `type` selects the cost variant (`:normal`, `:hd`,
  `:enriched`) and `info` the field (`:material_id` the ore nameid,
  `:zeny_cost` the zeny). Returns `-1` for an empty/unknown slot, a variant
  that has no entry at the item's level, an unknown `type`/`info`, or an item
  with no refine entry. Pure read over the inventory snapshot + refine tables.
  """
  @spec getequiprefinecost(Ctx.t(), integer(), atom(), :material_id | :zeny_cost) :: integer()
  def getequiprefinecost(%Ctx{game_state: nil}, _slot, _type, _info),
    do: no_player!("getequiprefinecost/4")

  def getequiprefinecost(%Ctx{} = ctx, slot, type, info) do
    with {item, item_def} <- Internal.fetch_equipped(ctx, slot),
         {:ok, group, item_level} <- RefineDatabase.group_and_level(item_def),
         %{chances: chances} <- RefineDatabase.level_info(group, item_level, item.refine + 1),
         chance when not is_nil(chance) <- Map.get(chances, type) do
      case info do
        :material_id -> chance.material_nameid || -1
        :zeny_cost -> chance.price
        _ -> -1
      end
    else
      _ -> -1
    end
  end

  @doc """
  Counts how many of the given item/card ids are currently equipped (rAthena
  `isequippedcnt`): a non-card id counts the worn stack once per equipped
  copy, a card id counts each equipped card slot holding that card (duplicate
  ids are counted once, non-positive ids ignored). Pure read over the
  inventory snapshot; player needed.
  """
  @spec isequippedcnt(Ctx.t(), [integer()]) :: non_neg_integer()
  def isequippedcnt(%Ctx{game_state: nil}, _ids), do: no_player!("isequippedcnt/2")

  def isequippedcnt(%Ctx{game_state: gs}, ids) when is_list(ids) do
    equipped = gs.inventory |> Inventory.equipped_items() |> Map.values()

    ids
    |> Enum.uniq()
    |> Enum.reject(&(&1 <= 0))
    |> Enum.reduce(0, fn id, acc -> acc + equip_count(equipped, id) end)
  end

  defp equip_count(equipped, id) do
    if card_item?(id) do
      equipped
      |> Enum.flat_map(&InventoryItem.cards/1)
      |> Enum.count(&(&1 == id))
    else
      equipped
      |> Enum.filter(&(&1.nameid == id))
      |> Enum.sum_by(& &1.amount)
    end
  end

  @spec card_item?(integer()) :: boolean()
  defp card_item?(id) do
    case ItemManagement.get_item_by_id(id) do
      {:ok, %ItemDefinition{type: :card}} -> true
      _ -> false
    end
  end

  @doc """
  A static field of an item by `type` code (rAthena `getiteminfo`): the
  `ITEMINFO_*` integer field selector. `item` is a nameid or an Aegis/display
  name. Fields Aesir does not model (item max-chance, gender, alias name)
  return `-1`; `ITEMINFO_AEGISNAME` (`18`) returns the Aegis name string.
  Unknown items return `""` for `ITEMINFO_AEGISNAME` and `-1` otherwise; an
  unknown `type` code returns `-1` (both matching rAthena's defaults). A pure
  read over the item database that never raises — no player is required.
  """
  @spec getiteminfo(Ctx.t(), integer() | String.t(), integer()) :: integer() | String.t()
  def getiteminfo(%Ctx{}, item, type) do
    case resolve_item(item) do
      {:ok, %ItemDefinition{} = definition} -> iteminfo_value(definition, type)
      {:error, _} -> iteminfo_missing(type)
    end
  end

  @doc """
  Returns a mob's display name for `MOB_NAME` (`type = 1`).

  `mob` accepts a numeric id or Aegis name. Unknown mobs return `"null"`;
  unsupported selectors return `-1`. This read does not require a player.
  """
  @spec getmonsterinfo(Ctx.t(), integer() | String.t(), integer()) :: String.t() | -1
  def getmonsterinfo(%Ctx{}, mob, 1) do
    case resolve_mob(mob) do
      {:ok, %MobDefinition{name: name}} -> name
      :error -> "null"
    end
  end

  def getmonsterinfo(%Ctx{}, _mob, _type), do: -1

  @spec resolve_mob(integer() | String.t()) :: {:ok, MobDefinition.t()} | :error
  defp resolve_mob(mob) when is_integer(mob), do: Mobs.by_id(mob)
  defp resolve_mob(mob) when is_binary(mob), do: Mobs.by_name(mob)

  # `getiteminfo` accepts a nameid or an Aegis name string.
  @spec resolve_item(integer() | String.t()) ::
          {:ok, ItemDefinition.t()} | {:error, :item_not_found}
  defp resolve_item(item) when is_integer(item), do: ItemManagement.get_item_by_id(item)
  defp resolve_item(item) when is_binary(item), do: ItemManagement.get_item_by_aegis(item)

  # rAthena `enum weapon_type` ordinals, mapped from the importer's subtype
  # atoms. `W_2HMACE` (9) is unused and has no atom; ammo/non-weapon subtypes
  # have no `W_*` equivalent and return `-1`.
  @weapon_subtypes %{
    dagger: 1,
    one_handed_sword: 2,
    two_handed_sword: 3,
    one_handed_spear: 4,
    two_handed_spear: 5,
    one_handed_axe: 6,
    two_handed_axe: 7,
    mace: 8,
    staff: 10,
    bow: 11,
    knuckle: 12,
    musical: 13,
    whip: 14,
    book: 15,
    katar: 16,
    revolver: 17,
    rifle: 18,
    gatling: 19,
    shotgun: 20,
    grenade: 21,
    huuma: 22,
    two_handed_staff: 23
  }

  defp weapon_subtype(%ItemDefinition{subtype: subtype}) when is_atom(subtype),
    do: Map.get(@weapon_subtypes, subtype, -1)

  defp weapon_subtype(%ItemDefinition{}), do: -1

  defp iteminfo_fields do
    %{
      0 => & &1.buy,
      1 => & &1.sell,
      2 => &ClientItemType.to_client_type(&1.type),
      3 => fn _ -> -1 end,
      4 => fn _ -> -1 end,
      5 => &EquipLocation.location_atoms_to_bitmask(&1.locations),
      6 => & &1.weight,
      7 => & &1.attack,
      8 => & &1.defense,
      9 => & &1.range,
      10 => & &1.slots,
      11 => & &1.view,
      12 => & &1.equip_level_min,
      # Weapon/armor level read as 0 unless the item is the matching type.
      13 => fn definition ->
        if definition.type == :weapon, do: definition.weapon_level || 0, else: 0
      end,
      14 => fn _ -> -1 end,
      15 => & &1.equip_level_max,
      16 => & &1.magic_attack,
      17 => & &1.id,
      18 => & &1.aegis_name,
      19 => fn definition ->
        if definition.type == :armor, do: definition.armor_level || 0, else: 0
      end,
      20 => &weapon_subtype/1
    }
  end

  defp iteminfo_value(%ItemDefinition{} = definition, type) do
    case Map.get(iteminfo_fields(), type) do
      fun when is_function(fun, 1) -> fun.(definition)
      nil -> -1
    end
  end

  defp iteminfo_missing(18), do: ""
  defp iteminfo_missing(_type), do: -1

  @doc """
  The number `n` with its English ordinal suffix (rAthena `F_GetNumSuffix`):
  `1` -> `"1st"`, `2` -> `"2nd"`, `3` -> `"3rd"`, `4`/`11`/`12`/`13` -> `"th"`.
  A pure helper; the ctx is ignored.
  """
  @spec num_suffix(Ctx.t(), integer()) :: String.t()
  def num_suffix(%Ctx{}, n) when is_integer(n), do: "#{n}#{ordinal_suffix(n)}"

  defp ordinal_suffix(n) when rem(n, 10) == 1 and n != 11, do: "st"
  defp ordinal_suffix(n) when rem(n, 10) == 2 and n != 12, do: "nd"
  defp ordinal_suffix(n) when rem(n, 10) == 3 and n != 13, do: "rd"
  defp ordinal_suffix(_n), do: "th"

  @doc """
  Formats a number with comma thousands separators (rAthena `F_InsertComma`):
  `1000000` -> `"1,000,000"`. Mirrors rAthena's algorithm — commas inserted
  every three characters from the right of the string form, so a leading sign
  counts as a character (`-1000` -> `"-1,000"`). A pure helper; ctx is ignored.
  """
  @spec insert_comma(Ctx.t(), integer() | String.t()) :: String.t()
  def insert_comma(%Ctx{}, value), do: value |> to_string() |> group_thousands()

  defp group_thousands(str) when byte_size(str) <= 3, do: str

  defp group_thousands(str) do
    (String.length(str) - 3)..1//-3
    |> Enum.reduce(str, fn index, acc ->
      {head, tail} = String.split_at(acc, index)
      head <> "," <> tail
    end)
  end

  @doc """
  The char id of the player's marriage partner (rAthena `getpartnerid`), or `0`
  when unmarried. Aesir has no marriage system yet, so `partner_id` is sourced
  once from the Character at spawn and is currently always `0`. Pure read over
  the ctx snapshot.
  """
  @spec getpartnerid(Ctx.t()) :: non_neg_integer()
  def getpartnerid(%Ctx{game_state: nil}), do: no_player!("getpartnerid/1")
  def getpartnerid(%Ctx{game_state: gs}), do: gs.partner_id

  @doc """
  A renewal build-flag check (rAthena `checkre`): `1` when the feature is
  compiled in, else `0`. Aesir is renewal-only, so every renewal feature
  (`0` RENEWAL / `1` cast / `2` drop / `3` exp / `4` level-damage / `5` ASPD)
  is on and returns `1`; any unknown type returns `0`, matching rAthena. Pure
  read; the ctx is ignored.
  """
  @spec checkre(Ctx.t(), integer()) :: 0 | 1
  def checkre(%Ctx{}, type) when type in 0..5, do: 1
  def checkre(%Ctx{}, _type), do: 0

  @doc """
  A VIP status query (rAthena `vip_status`): active flag / expiry timestamp /
  remaining seconds by `type`. Aesir has no VIP tier, so this mirrors
  rAthena's non-VIP build and always returns `0` for every type. Pure read;
  the ctx is ignored.
  """
  @spec vip_status(Ctx.t(), integer()) :: 0
  def vip_status(%Ctx{}, _type), do: 0

  @doc """
  The current time as an integer tick (rAthena `gettimetick`), by `type`:
  `2` the Unix epoch timestamp in seconds, `1` the seconds elapsed since
  local midnight (`0..86_399`, server local time as everywhere else),
  `0` (and any other type, matching rAthena's default case) the system
  tick — milliseconds since the VM started, monotonic, meant only for
  elapsed-time math. Pure read; the ctx is ignored.
  """
  @spec gettimetick(Ctx.t(), integer()) :: integer()
  def gettimetick(%Ctx{}, 2), do: System.os_time(:second)

  def gettimetick(%Ctx{}, 1) do
    %NaiveDateTime{hour: hour, minute: minute, second: second} = NaiveDateTime.local_now()
    hour * 3600 + minute * 60 + second
  end

  def gettimetick(%Ctx{}, _type) do
    vm_start = System.convert_time_unit(:erlang.system_info(:start_time), :native, :millisecond)
    System.monotonic_time(:millisecond) - vm_start
  end

  @doc """
  A calendar-date component in server local time (rAthena `gettime`), selected
  by `type` (the `DT_*` constants, 1-9). Invalid selectors return `-1`.
  Pure read; the ctx is ignored.
  """
  @spec gettime(Ctx.t(), integer()) :: integer()
  def gettime(%Ctx{}, type), do: Rathena.gettime(NaiveDateTime.local_now(), type)

  @doc """
  The unit id (gid) of the NPC running the script (rAthena `getnpcid`, type-0
  form). A pure read that does not raise on a detached ctx — the NPC identity
  is not player state — and returns `0` when there is no `npc_gid` (e.g. an
  item script), matching rAthena's "no NPC attached" result.
  """
  @spec getnpcid(Ctx.t()) :: non_neg_integer()
  def getnpcid(%Ctx{npc_gid: nil}), do: 0
  def getnpcid(%Ctx{npc_gid: gid}), do: gid

  @doc """
  The unit id (gid) of the first NPC registered under `name`
  (rAthena `getnpcid(0,"name")`), or `0` when the name resolves to no
  placement.
  """
  @spec getnpcid(Ctx.t(), String.t()) :: non_neg_integer()
  def getnpcid(%Ctx{}, name) do
    case NpcRegistry.by_name(name) do
      [{_module, placement} | _rest] -> NpcRegistry.entity_id(placement)
      [] -> 0
    end
  end

  @doc """
  The account id of the player attached to the script, or `0` when none is
  (rAthena `playerattached`). A pure read that does not raise on a detached
  ctx — its whole purpose is to test for attachment, so an event/timer ctx
  returns `0` rather than crashing.
  """
  @spec playerattached(Ctx.t()) :: non_neg_integer()
  def playerattached(%Ctx{account_id: nil}), do: 0
  def playerattached(%Ctx{account_id: account_id}), do: account_id

  @doc """
  An id of the attached player by `type` (rAthena `getcharid`): `0` the char
  id, `1` the party id (`0` when partyless), `2` the guild id (`0` when
  guildless), `3` the account id. Any other type returns `0`, matching
  rAthena. Pure read over the ctx snapshot.
  """
  @spec getcharid(Ctx.t(), integer()) :: non_neg_integer()
  def getcharid(%Ctx{game_state: nil}, _type), do: no_player!("getcharid/2")
  def getcharid(%Ctx{char_id: char_id}, 0), do: char_id
  def getcharid(%Ctx{game_state: gs}, 1), do: gs.party_id
  def getcharid(%Ctx{game_state: gs}, 2), do: gs.guild_id || 0
  def getcharid(%Ctx{account_id: account_id}, 3), do: account_id
  def getcharid(%Ctx{}, _type), do: 0

  @doc "Returns the guild name for `guild_id`, or `\"null\"` when no guild exists."
  @spec getguildname(Ctx.t(), integer()) :: String.t()
  def getguildname(%Ctx{}, guild_id) do
    case GuildManager.get(guild_id) do
      {:ok, %GuildState{name: name}} -> name
      {:error, :not_found} -> "null"
    end
  end

  @doc """
  Whether the attached player is the leader of their party (rAthena
  `is_party_leader`); with a `party_id`, whether they lead that party. Returns
  `1` (leader) or `0` (not leader / no party / unknown party). Pure read that
  consults the live party entry; a detached ctx raises.
  """
  @spec party_leader?(Ctx.t()) :: 0 | 1
  def party_leader?(%Ctx{game_state: nil}), do: no_player!("party_leader?/1")

  def party_leader?(%Ctx{game_state: gs} = ctx), do: party_leader?(ctx, gs.party_id)

  @spec party_leader?(Ctx.t(), non_neg_integer()) :: 0 | 1
  def party_leader?(%Ctx{game_state: nil}, _party_id), do: no_player!("party_leader?/2")

  def party_leader?(%Ctx{game_state: gs}, party_id) do
    case PartyManager.get(party_id) do
      {:ok, %PartyState{leader_char_id: leader}} -> if leader == gs.character_id, do: 1, else: 0
      {:error, _reason} -> 0
    end
  end

  @doc """
  A field of the running NPC's info as a string (rAthena `strnpcinfo`):
  `0` the full name including the hidden `#`-fragment, `1` the visible name,
  `2` the hidden fragment, `3` the unique name, `4` the map name; the file
  path (`5`) is not modelled and returns an empty string. The hidden fragment
  exists only when the placement's `unique_name` is the rAthena full-name form
  `<visible>#<hidden>` (what the transpiler emits for duplicates); otherwise
  `0` falls back to the visible name and `2` is empty. A pure read that does
  not raise on a detached ctx; an absent or unresolvable `npc_gid` returns an
  empty string, matching rAthena's "no NPC" result.
  """
  @spec strnpcinfo(Ctx.t(), integer()) :: String.t()
  def strnpcinfo(%Ctx{npc_gid: nil}, _type), do: ""

  def strnpcinfo(%Ctx{npc_gid: gid}, type) do
    case NpcRegistry.module_for_unit(gid) do
      {:ok, {_module, placement}} -> npc_info(placement, type)
      :error -> ""
    end
  end

  defp npc_info(%{name: name} = placement, 0) do
    case npc_hidden_fragment(placement) do
      "" -> name
      hidden -> name <> "#" <> hidden
    end
  end

  defp npc_info(%{name: name}, 1), do: name
  defp npc_info(%{} = placement, 2), do: npc_hidden_fragment(placement)
  defp npc_info(%{unique_name: unique_name}, 3), do: unique_name
  defp npc_info(%{map: map}, 4), do: map
  defp npc_info(_placement, _type), do: ""

  defp npc_hidden_fragment(%{name: name, unique_name: unique_name}) do
    case String.split(unique_name, "#", parts: 2) do
      [^name, hidden] -> hidden
      _other -> ""
    end
  end
end
