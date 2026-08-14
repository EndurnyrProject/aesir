defmodule Aesir.ZoneServer.Npc.Transpiler.Resolver do
  @moduledoc """
  Resolves rAthena NPC script symbols at transpile time.

  Statuses, classes, elements, items and skills delegate to the item
  transpiler's curated `RathenaScript.Resolver`. On top of that this module
  resolves bare constants (`true`/`false`, `VIP_STATUS_*`, `Job_*`, `SC_*`,
  `Ele_*`) for expression codegen, and NPC sprite constants (`4_F_KAFRA1`) via the
  `e_job_types` enum parsed straight out of rAthena's `src/map/npc.hpp` — the
  same table rAthena itself uses (script sprite names are the enum entries
  minus their `JT_` prefix).

  A symbol that resolves nowhere returns `:error`; the codegen then emits a
  raising `Todo.const!/1` and the report lists it.
  """

  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Mmo.Emotion
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver, as: ItemResolver
  alias Aesir.ZoneServer.Mmo.JobManagement.JobMapid

  @doc """
  Resolves a bare constant to an Elixir literal source string: booleans to
  `1`/`0` (rAthena semantics), `bc_*` broadcast flags to their integer value,
  job/status/element constants to their Aesir atoms.
  """
  @spec constant(String.t()) :: {:ok, String.t()} | :error
  def constant("true"), do: {:ok, "1"}
  def constant("false"), do: {:ok, "0"}

  def constant("VIP_STATUS_ACTIVE"), do: {:ok, "1"}
  def constant("VIP_STATUS_EXPIRE"), do: {:ok, "2"}
  def constant("VIP_STATUS_REMAINING"), do: {:ok, "3"}

  # The `skill` buildin's permanent-grant mode; the only mode the DSL grant
  # implements, emitted as its native atom rather than a char-var lookup.
  def constant("SKILL_PERM"), do: {:ok, ":permanent"}

  # rAthena refine cost variants, emitted as the `RefineDatabase.cost_type`
  # atoms `getequiprefinecost`/`getequippercentrefinery` select on.
  def constant("REFINE_COST_NORMAL"), do: {:ok, ":normal"}
  def constant("REFINE_COST_HD"), do: {:ok, ":hd"}
  def constant("REFINE_COST_ENRICHED"), do: {:ok, ":enriched"}

  # rAthena `getequiprefinecost` third-argument selectors, emitted as the
  # atoms the DSL switches on.
  def constant("REFINE_MATERIAL_ID"), do: {:ok, ":material_id"}
  def constant("REFINE_ZENY_COST"), do: {:ok, ":zeny_cost"}

  # rAthena `enum iteminfo` field selectors (`getiteminfo`'s second argument).
  def constant("ITEMINFO_BUY"), do: {:ok, "0"}
  def constant("ITEMINFO_SELL"), do: {:ok, "1"}
  def constant("ITEMINFO_TYPE"), do: {:ok, "2"}
  def constant("ITEMINFO_MAXCHANCE"), do: {:ok, "3"}
  def constant("ITEMINFO_GENDER"), do: {:ok, "4"}
  def constant("ITEMINFO_LOCATIONS"), do: {:ok, "5"}
  def constant("ITEMINFO_WEIGHT"), do: {:ok, "6"}
  def constant("ITEMINFO_ATTACK"), do: {:ok, "7"}
  def constant("ITEMINFO_DEFENSE"), do: {:ok, "8"}
  def constant("ITEMINFO_RANGE"), do: {:ok, "9"}
  def constant("ITEMINFO_SLOT"), do: {:ok, "10"}
  def constant("ITEMINFO_VIEW"), do: {:ok, "11"}
  def constant("ITEMINFO_EQUIPLEVELMIN"), do: {:ok, "12"}
  def constant("ITEMINFO_WEAPONLEVEL"), do: {:ok, "13"}
  def constant("ITEMINFO_ALIASNAME"), do: {:ok, "14"}
  def constant("ITEMINFO_EQUIPLEVELMAX"), do: {:ok, "15"}
  def constant("ITEMINFO_MAGICATTACK"), do: {:ok, "16"}
  def constant("ITEMINFO_ID"), do: {:ok, "17"}
  def constant("ITEMINFO_AEGISNAME"), do: {:ok, "18"}
  def constant("ITEMINFO_ARMORLEVEL"), do: {:ok, "19"}
  def constant("ITEMINFO_SUBTYPE"), do: {:ok, "20"}

  def constant(symbol) do
    case job_mapid_constant(symbol) do
      {:ok, value} ->
        {:ok, Integer.to_string(value)}

      :error ->
        case weapon_subtype_constant(symbol) do
          {:ok, value} -> {:ok, Integer.to_string(value)}
          :error -> constant_fallback(symbol)
        end
    end
  end

  # `EAJ_*`/`EAJL_*` job-system constants, delegated to `JobMapid`.
  defp job_mapid_constant(symbol), do: JobMapid.constant(symbol)

  defp constant_fallback(symbol) do
    case flag_constant(symbol) do
      {:ok, _} = ok ->
        ok

      :error ->
        [
          &ItemResolver.resolve_class/1,
          &ItemResolver.resolve_status/1,
          &ItemResolver.resolve_element/1
        ]
        |> Enum.find_value(:error, &atom_constant(&1, symbol))
    end
  end

  # rAthena `enum weapon_type` ordinals, so `getiteminfo(.., ITEMINFO_SUBTYPE)
  # == W_1HSWORD` comparisons render against integer literals.
  @weapon_subtypes %{
    "W_FIST" => 0,
    "W_DAGGER" => 1,
    "W_1HSWORD" => 2,
    "W_2HSWORD" => 3,
    "W_1HSPEAR" => 4,
    "W_2HSPEAR" => 5,
    "W_1HAXE" => 6,
    "W_2HAXE" => 7,
    "W_MACE" => 8,
    "W_2HMACE" => 9,
    "W_STAFF" => 10,
    "W_BOW" => 11,
    "W_KNUCKLE" => 12,
    "W_MUSICAL" => 13,
    "W_WHIP" => 14,
    "W_BOOK" => 15,
    "W_KATAR" => 16,
    "W_REVOLVER" => 17,
    "W_RIFLE" => 18,
    "W_GATLING" => 19,
    "W_SHOTGUN" => 20,
    "W_GRENADE" => 21,
    "W_HUUMA" => 22,
    "W_2HSTAFF" => 23
  }

  defp weapon_subtype_constant(symbol) when is_binary(symbol),
    do: Map.fetch(@weapon_subtypes, symbol)

  defp flag_constant(symbol) do
    case Flags.value(symbol) do
      {:ok, value} -> {:ok, Integer.to_string(value)}
      :error -> :error
    end
  end

  defp atom_constant(resolver, symbol) do
    case resolver.(symbol) do
      {:ok, atom} -> {:ok, inspect(atom)}
      {:error, _} -> nil
    end
  end

  @spec item(String.t() | integer()) :: {:ok, integer()} | :error
  def item(symbol) do
    case ItemResolver.resolve_item(symbol) do
      {:ok, id} -> {:ok, id}
      {:error, _} -> :error
    end
  end

  @doc "Resolves an `IG_*` constant to a known item-group key."
  @spec item_group(String.t()) :: {:ok, atom()} | :error
  def item_group(symbol) do
    case ItemResolver.resolve_item_group(symbol) do
      {:ok, key} -> {:ok, key}
      {:error, _} -> :error
    end
  end

  @spec status(String.t()) :: {:ok, atom()} | :error
  def status(symbol) do
    case ItemResolver.resolve_status(symbol) do
      {:ok, atom} -> {:ok, atom}
      {:error, _} -> :error
    end
  end

  @spec bound(String.t()) :: {:ok, 1 | 4} | :error
  def bound(symbol) do
    case ItemResolver.resolve_bound(symbol) do
      {:ok, value} -> {:ok, value}
      {:error, _} -> :error
    end
  end

  @spec skill(String.t() | integer()) :: {:ok, integer()} | :error
  def skill(symbol) do
    case ItemResolver.resolve_skill(symbol) do
      {:ok, id} -> {:ok, id}
      {:error, _} -> :error
    end
  end

  @doc """
  Resolves an `emotion` buildin argument. An `ET_*` token maps to its
  `Mmo.Emotion` atom key (`ET_MONEY` -> `:money`), validated against
  `Emotion.id/1`. A bare integer passes through unchanged, matching the
  `emotion` DSL op's `atom() | non_neg_integer()` argument.
  """
  @spec emote(String.t() | integer()) :: {:ok, atom() | integer()} | :error
  def emote(value) when is_integer(value), do: {:ok, value}

  def emote("ET_" <> _ = symbol) do
    Code.ensure_loaded(Emotion)

    with {:ok, atom} <- existing_atom(String.trim_leading(symbol, "ET_")),
         id when is_integer(id) <- Emotion.id(atom) do
      {:ok, atom}
    else
      _ -> :error
    end
  end

  def emote(symbol) when is_binary(symbol), do: :error

  @doc """
  Resolves a `specialeffect`/`specialeffect2` effect argument. An `EF_*` token
  maps to its readable `:ef_*` atom (delegating the id-validity check to
  `ItemResolver.resolve_effect/1`); a bare integer passes through unchanged,
  matching the effect DSL ops' `atom() | non_neg_integer()` argument.
  """
  @spec effect(String.t() | integer()) :: {:ok, atom() | integer()} | :error
  def effect(value) when is_integer(value), do: {:ok, value}

  def effect(symbol) when is_binary(symbol) do
    case ItemResolver.resolve_effect(symbol) do
      {:ok, atom} -> {:ok, atom}
      {:error, _} -> :error
    end
  end

  # rAthena `enum equip_index` (`src/map/pc.hpp`): the ordinal slot index a
  # `getequipid` argument names. The DSL maps the index back to an Aesir equip
  # location, so only the index travels through the transpiler.
  @equip_slots %{
    "EQI_ACC_L" => 0,
    "EQI_ACC_R" => 1,
    "EQI_SHOES" => 2,
    "EQI_GARMENT" => 3,
    "EQI_HEAD_LOW" => 4,
    "EQI_HEAD_MID" => 5,
    "EQI_HEAD_TOP" => 6,
    "EQI_ARMOR" => 7,
    "EQI_HAND_L" => 8,
    "EQI_HAND_R" => 9,
    "EQI_COSTUME_HEAD_TOP" => 10,
    "EQI_COSTUME_HEAD_MID" => 11,
    "EQI_COSTUME_HEAD_LOW" => 12,
    "EQI_COSTUME_GARMENT" => 13,
    "EQI_AMMO" => 14,
    "EQI_SHADOW_ARMOR" => 15,
    "EQI_SHADOW_WEAPON" => 16,
    "EQI_SHADOW_SHIELD" => 17,
    "EQI_SHADOW_SHOES" => 18,
    "EQI_SHADOW_ACC_R" => 19,
    "EQI_SHADOW_ACC_L" => 20
  }

  @doc """
  Resolves a `getequipid` equip-slot argument. An `EQI_*` token maps to its
  rAthena `equip_index` ordinal; a bare integer passes through unchanged
  (scripts also index equipment slots with plain variables/ints).
  """
  @spec equip_slot(String.t() | integer()) :: {:ok, integer()} | :error
  def equip_slot(value) when is_integer(value), do: {:ok, value}
  def equip_slot(symbol) when is_binary(symbol), do: Map.fetch(@equip_slots, symbol)

  # rAthena `enum _look` (`src/map/map.hpp`): the look-type ids `getlook`/
  # `setlook` accept, plus the `VAR_*` aliases script_constants.hpp exports
  # for the same enum. Only the integer look id travels through the transpiler.
  @look_types %{
    "LOOK_BASE" => 0,
    "LOOK_HAIR" => 1,
    "LOOK_WEAPON" => 2,
    "LOOK_HEAD_BOTTOM" => 3,
    "LOOK_HEAD_TOP" => 4,
    "LOOK_HEAD_MID" => 5,
    "LOOK_HAIR_COLOR" => 6,
    "LOOK_CLOTHES_COLOR" => 7,
    "LOOK_SHIELD" => 8,
    "LOOK_SHOES" => 9,
    "LOOK_BODY" => 10,
    "LOOK_RESET_COSTUMES" => 11,
    "LOOK_ROBE" => 12,
    "LOOK_BODY2" => 13,
    "VAR_HEAD" => 1,
    "VAR_WEAPON" => 2,
    "VAR_HEAD_BOTTOM" => 3,
    "VAR_HEAD_TOP" => 4,
    "VAR_HEAD_MID" => 5,
    "VAR_HEADPALETTE" => 6,
    "VAR_BODYPALETTE" => 7,
    "VAR_SHOES" => 9
  }

  @doc """
  Resolves a `getlook`/`setlook` look-type argument. A `LOOK_*` or `VAR_*`
  token maps to its rAthena `enum _look` id; a bare integer passes through
  unchanged (scripts also spell the look type as a literal/variable).
  """
  @spec look(String.t() | integer()) :: {:ok, non_neg_integer()} | :error
  def look(value) when is_integer(value), do: {:ok, value}
  def look(symbol) when is_binary(symbol), do: Map.fetch(@look_types, symbol)

  # The rAthena `cell_*` constants a `setcell` type argument accepts, mapped to
  # the trait atom the Script DSL consumes. The unsupported members still
  # resolve (ScriptCells warns and no-ops on them at runtime, per spec).
  @cell_types %{
    "cell_walkable" => :walkable,
    "cell_shootable" => :shootable,
    "cell_water" => :water,
    "cell_npc" => :npc,
    "cell_basilica" => :basilica,
    "cell_landprotector" => :landprotector,
    "cell_novending" => :novending,
    "cell_nochat" => :nochat,
    "cell_maelstrom" => :maelstrom,
    "cell_icewall" => :icewall,
    "cell_nobuyingstore" => :nobuyingstore
  }

  @doc """
  Resolves a `setcell` cell-type constant (`cell_*`) to its trait atom,
  case-insensitively (scripts spell both `cell_icewall` and `CELL_WALKABLE`).
  Unknown strings return `:error`.
  """
  @spec cell_type(String.t()) :: {:ok, atom()} | :error
  def cell_type(symbol) when is_binary(symbol) do
    Map.fetch(@cell_types, String.downcase(symbol))
  end

  @quest_modes %{
    "HAVEQUEST" => :havequest,
    "PLAYTIME" => :playtime,
    "HUNTING" => :hunting
  }

  @doc """
  Resolves a `checkquest`/`questprogress` mode constant (`HAVEQUEST`,
  `PLAYTIME`, `HUNTING`) to the `QuestLog.check/3` mode atom. rAthena spells
  these uppercase; unlike buildin names they are not case-insensitive.
  """
  @spec quest_mode(String.t()) :: {:ok, :havequest | :playtime | :hunting} | :error
  def quest_mode(symbol) when is_binary(symbol), do: Map.fetch(@quest_modes, symbol)

  # -- sprites -----------------------------------------------------------------

  @doc """
  Parses the `e_job_types` enum from rAthena's `src/map/npc.hpp` into a
  `%{"4_F_KAFRA1" => id}` map. Plain C enum: explicit `= N` anchors, +1
  otherwise; `JT_` prefixes stripped to match script sprite names.
  """
  @spec load_sprites(Path.t()) :: {:ok, %{String.t() => integer()}} | {:error, term()}
  def load_sprites(npc_hpp_path) do
    with {:ok, source} <- File.read(npc_hpp_path),
         [_, body] <- Regex.run(~r/enum e_job_types\s*\{(.*?)\};/s, source) do
      {:ok, parse_enum(body)}
    else
      nil -> {:error, :enum_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_enum(body) do
    body
    |> String.replace(~r{//[^\n]*}, "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reduce({%{}, 0}, &enum_entry/2)
    |> elem(0)
  end

  defp enum_entry(entry, {acc, next}) do
    case Regex.run(~r/^(\w+)\s*(?:=\s*(-?\w+))?/, entry) do
      [_, name] -> {put_sprite(acc, name, next), next + 1}
      [_, name, value] -> with_value(acc, name, value, next)
      nil -> {acc, next}
    end
  end

  defp with_value(acc, name, value, next) do
    case Integer.parse(value) do
      {n, ""} -> {put_sprite(acc, name, n), n + 1}
      # `= OTHER_CONST` anchors (e.g. NPC_RANGE2_END) don't advance the counter
      _ -> {acc, next}
    end
  end

  defp put_sprite(acc, "JT_" <> name, value), do: Map.put(acc, name, value)
  defp put_sprite(acc, _other, _value), do: acc

  @spec existing_atom(String.t()) :: {:ok, atom()} | :error
  defp existing_atom(symbol) do
    {:ok, String.to_existing_atom(String.downcase(symbol))}
  rescue
    ArgumentError -> :error
  end
end
