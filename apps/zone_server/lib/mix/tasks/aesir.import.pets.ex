defmodule Mix.Tasks.Aesir.Import.Pets do
  @shortdoc "Imports the mode-selected pet database"
  @moduledoc """
  Imports rAthena's `pet_db` for one mode into `priv/db/<mode>/pets.yml`.

      mix aesir.import.pets [<rathena_root>] [--mode re|pre-re]

  Rows are parsed as `PetDatabase::parseBodyNode` (`pet.cpp`) does: absent
  fields take its defaults, `Fullness` is capped at 100 and `IntimacyStart`,
  `CaptureRate` and the three AI rates at 10000, and `HungryDelay` seconds are
  stored as milliseconds. Mob and item aegis names resolve case-insensitively
  against the same mode's rAthena `mob_db` and `item_db`, the lowest id winning
  a mob name shared by several ids. `Script` becomes an `EquipScript` source
  string and `SupportScript` a list of support ops. Where the reference skips a
  row with a warning (unknown name, missing mandatory field), the import fails.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.PetManagement.SupportScript
  alias Mix.Tasks.Aesir.Import

  @max_amount 30_000

  @typedoc "Case-insensitive aegis-name indexes: lowercase name to id."
  @type resolvers :: %{mob: %{String.t() => pos_integer()}, item: %{String.t() => pos_integer()}}

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    Application.put_env(:commons, :game_mode, mode)
    out = Import.path("pets.yml", mode)

    item_rows = rows_by_id(rathena, "item_db.yml", mode)
    mob_rows = rows_by_id(rathena, "mob_db.yml", mode)
    pet_rows = Import.read_mode_filtered!(Path.join([rathena, "db", "pet_db.yml"]), mode)
    resolvers = resolvers(item_rows, mob_rows)
    source_catalogs = Resolver.source_catalogs(Map.values(item_rows), [])

    rows =
      Resolver.with_source_catalogs(source_catalogs, fn ->
        Enum.map(pet_rows, &to_row(&1, resolvers))
      end)

    reject_duplicates!(rows)
    rows = Enum.sort_by(rows, & &1["mob_id"])

    File.mkdir_p!(Path.dirname(out))
    File.write!(out, Ymlr.document!(rows, sort_maps: true))
    Mix.shell().info("pets: #{length(rows)} -> #{out}")
  end

  @doc false
  @spec to_row(map(), resolvers()) :: map()
  def to_row(source, resolvers) do
    for field <- ~w(Mob EggItem Fullness CaptureRate), not Map.has_key?(source, field) do
      Mix.raise("pet row #{inspect(source["Mob"])} is missing #{field}")
    end

    %{
      "mob_id" => mob!(resolvers, source["Mob"]),
      "tame_item_id" => optional_item(resolvers, source["TameItem"]),
      "egg_item_id" => item!(resolvers, source["EggItem"]),
      "equip_item_id" => optional_item(resolvers, source["EquipItem"]),
      "food_item_id" => optional_item(resolvers, source["FoodItem"]),
      "fullness" => min(uint(source["Fullness"], 16), 100),
      "hungry_delay_ms" =>
        Integer.mod(uint(Map.get(source, "HungryDelay", 60), 32) * 1000, 4_294_967_296),
      "hunger_increase" => int32(Map.get(source, "HungerIncrease", 20)),
      "intimacy_start" => source |> Map.get("IntimacyStart", 250) |> uint(32) |> min(10_000),
      "intimacy_fed" => int32(Map.get(source, "IntimacyFed", 50)),
      "intimacy_overfed" => int32(Map.get(source, "IntimacyOverfed", -100)),
      "intimacy_hungry" => int32(Map.get(source, "IntimacyHungry", -5)),
      "intimacy_owner_die" => int32(Map.get(source, "IntimacyOwnerDie", -20)),
      "capture_rate" => min(uint(source["CaptureRate"], 16), 10_000),
      "special_performance" => Map.get(source, "SpecialPerformance", true),
      "attack_rate" => rate(source["AttackRate"]),
      "retaliate_rate" => rate(source["RetaliateRate"]),
      "change_target_rate" => rate(source["ChangeTargetRate"]),
      "allow_auto_feed" => Map.get(source, "AllowAutoFeed", false),
      "bonus_program" => bonus_program!(source["Mob"], source["Script"]),
      "support_ops" => support_ops(source["SupportScript"]),
      "evolution" => evolution!(resolvers, source["Evolution"] || [])
    }
  end

  defp uint(value, bits) when is_integer(value) and value >= 0,
    do: Integer.mod(value, Integer.pow(2, bits))

  defp uint(value, _bits), do: Mix.raise("invalid unsigned integer #{inspect(value)}")

  defp int32(value) when is_integer(value),
    do: Integer.mod(value + 2_147_483_648, 4_294_967_296) - 2_147_483_648

  defp rate(nil), do: 10_001
  defp rate(value), do: min(uint(value, 16), 10_000)

  defp bonus_program!(_mob, nil), do: nil

  defp bonus_program!(mob, script) do
    case Transpiler.transpile_equip(script) do
      {:ok, program} -> EquipScript.to_source(program)
      {:error, reason} -> Mix.raise("pet #{mob} Script does not transpile: #{inspect(reason)}")
    end
  end

  defp support_ops(nil), do: []

  defp support_ops(script) do
    script
    |> SupportScript.transpile()
    |> Enum.map(fn op -> op |> Tuple.to_list() |> Enum.map(&encode/1) end)
  end

  defp encode(value) when is_atom(value), do: Atom.to_string(value)
  defp encode(value), do: value

  defp evolution!(resolvers, evolutions) do
    evolutions
    |> Enum.map(fn evolution ->
      requirements =
        Enum.map(
          evolution["ItemRequirements"] || missing_requirements!(evolution),
          &requirement!(resolvers, &1)
        )

      {mob!(resolvers, evolution["Target"]), requirements}
    end)
    |> merge_in_order()
    |> Enum.map(fn {target, requirements} ->
      %{
        "target_mob_id" => target,
        "requirements" =>
          requirements
          |> merge_in_order()
          |> Enum.map(fn {item_id, amount} -> %{"item_id" => item_id, "amount" => amount} end)
      }
    end)
  end

  defp requirement!(resolvers, %{"Item" => item, "Amount" => amount}) do
    amount = uint(amount, 16)
    if amount > @max_amount, do: Mix.raise("evolution amount #{amount} exceeds #{@max_amount}")
    {item!(resolvers, item), amount}
  end

  defp missing_requirements!(evolution),
    do: Mix.raise("evolution #{inspect(evolution["Target"])} is missing ItemRequirements")

  # A repeated target merges its requirements and a repeated item keeps the
  # later amount, as the reference's `evolution_data`/`requirements` maps do.
  defp merge_in_order(pairs) do
    pairs
    |> Enum.reduce({[], %{}}, fn {key, value}, {order, acc} ->
      case acc do
        %{^key => previous} when is_list(value) -> {order, %{acc | key => previous ++ value}}
        %{^key => _previous} -> {order, %{acc | key => value}}
        _ -> {[key | order], Map.put(acc, key, value)}
      end
    end)
    |> then(fn {order, acc} -> order |> Enum.reverse() |> Enum.map(&{&1, acc[&1]}) end)
  end

  defp optional_item(_resolvers, nil), do: 0
  defp optional_item(resolvers, name), do: item!(resolvers, name)

  defp item!(resolvers, name), do: fetch!(resolvers.item, name, "item")
  defp mob!(resolvers, name), do: fetch!(resolvers.mob, name, "mob")

  defp fetch!(index, name, kind) do
    case Map.fetch(index, String.downcase(name)) do
      {:ok, id} -> id
      :error -> Mix.raise("unknown #{kind} #{name}")
    end
  end

  defp reject_duplicates!(rows) do
    case rows |> Enum.frequencies_by(& &1["mob_id"]) |> Enum.filter(&(elem(&1, 1) > 1)) do
      [] -> :ok
      duplicates -> Mix.raise("duplicate pet rows for mobs #{inspect(Keyword.keys(duplicates))}")
    end
  end

  defp resolvers(item_rows, mob_rows) do
    %{
      item: Map.new(item_rows, fn {id, row} -> {String.downcase(row["AegisName"]), id} end),
      mob:
        mob_rows
        |> Enum.sort_by(fn {id, _row} -> id end, :desc)
        |> Map.new(fn {id, row} -> {String.downcase(row["AegisName"]), id} end)
    }
  end

  defp rows_by_id(rathena, file, mode) do
    [rathena, "db", file]
    |> Path.join()
    |> Import.read_mode_filtered!(mode)
    |> Enum.reduce(%{}, fn row, acc ->
      Map.update(acc, Map.fetch!(row, "Id"), row, &Map.merge(&1, row))
    end)
  end
end
