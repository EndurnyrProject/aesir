defmodule Mix.Tasks.Aesir.Import.ItemNoequip do
  @shortdoc "Imports rAthena's item_noequip.txt map-type restrictions into mode-scoped YAML"
  @moduledoc """
  Converts the mode's `db/<re|pre-re>/item_noequip.txt` into
  `apps/zone_server/priv/db/<mode>/item_noequip.yml`.

      mix aesir.import.item_noequip [<rathena_root>] [--mode re|pre-re]

  Each `ItemID,Flag` line applies in file order: a non-negative flag is OR-ed
  into the item's restriction mask and a negative one clears the bits of its
  absolute value. A line naming an item the mode's item database lacks is
  skipped and reported, as the reference skips it. Items whose mask ends at 0
  are not written; rows are sorted by item id.
  """
  use Mix.Task

  import Bitwise

  alias Mix.Tasks.Aesir.Import

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {source_root, mode} = Import.parse!(args)

    known =
      [source_root, "db", "item_db.yml"]
      |> Path.join()
      |> Import.read_mode_filtered!(mode)
      |> MapSet.new(& &1["Id"])

    {masks, unknown} =
      source_root
      |> Import.rathena_db_dir(mode)
      |> Path.join("item_noequip.txt")
      |> File.stream!()
      |> convert(known)

    out = Import.path("item_noequip.yml", mode)
    File.mkdir_p!(Path.dirname(out))
    File.write!(out, Ymlr.document!(masks, sort_maps: true))
    Mix.shell().info("item_noequip: #{length(masks)} items")

    unless unknown == [] do
      Mix.shell().info("  skipped unknown items: #{Enum.join(unknown, ", ")}")
    end

    :ok
  end

  @doc "Folds `ItemID,Flag` lines into the output rows and the unknown item ids."
  @spec convert(Enumerable.t(), MapSet.t(integer())) :: {[map()], [integer()]}
  def convert(lines, known) do
    {masks, unknown} =
      lines
      |> Enum.flat_map(&parse/1)
      |> Enum.reduce({%{}, []}, fn {id, flag}, {masks, unknown} ->
        if MapSet.member?(known, id),
          do: {Map.update(masks, id, apply_flag(0, flag), &apply_flag(&1, flag)), unknown},
          else: {masks, [id | unknown]}
      end)

    rows =
      for {id, mask} <- Enum.sort(masks), mask != 0, do: %{"item" => id, "flag" => mask}

    {rows, unknown |> Enum.reverse() |> Enum.uniq()}
  end

  defp apply_flag(mask, flag) when flag >= 0, do: bor(mask, flag)
  defp apply_flag(mask, flag), do: band(mask, bnot(abs(flag)))

  defp parse(line) do
    line = line |> String.split("//", parts: 2) |> hd() |> String.trim()

    with [id, flag] <- String.split(line, ","),
         {id, ""} <- Integer.parse(String.trim(id)),
         {flag, _rest} <- Integer.parse(String.trim(flag)) do
      [{id, flag}]
    else
      _ -> []
    end
  end
end
