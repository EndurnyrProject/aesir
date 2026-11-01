defmodule Aesir.ZoneServer.Content.Npc.Functions.FCashDungeon do
  @moduledoc """
  Offers the dungeon destinations for each dungeon teleport scroll.

  ## Behavior

  The first scroll hides Umbala in renewal without changing the logical menu
  positions. A selection warps and ends the calling script.

  ## Credits

  Original function by L0ne_W0lf, with dungeon-menu updates by Euphy.

  ## Adaptation

  LLM-assisted Elixir port of the shared Cash Shop function.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl

  @doc "Runs the dungeon menu selected by the first argument."
  @spec call(Ctx.t(), [integer()]) :: {Ctx.t(), integer()} | no_return()
  def call(ctx, args) do
    case destinations(Enum.at(args, 0, 0)) do
      [] ->
        {ctx, 0}

      entries ->
        {ctx, choice} = Dsl.select(ctx, Enum.map(entries, &elem(&1, 0)))
        {_label, {map, x, y}} = Enum.at(entries, choice - 1)
        ctx = Dsl.warp(ctx, map, x, y)
        throw({:script_end, ctx})
    end
  end

  defp destinations(1) do
    umbala = if GameMode.mode() == :renewal, do: "", else: "Umbala Dungeon"

    [
      {"Nogg Road", {"mag_dun01", 125, 71}},
      {"Mjolnir Dead Pit", {"mjo_dun02", 80, 297}},
      {umbala, {"um_dun02", 125, 122}},
      {"Einbroch Mine Dungeon", {"ein_dun01", 261, 262}},
      {"Payon Dungeon", {"pay_dun03", 155, 150}},
      {"Toy Dungeon", {"xmas_dun01", 133, 130}},
      {"Glast Heim Underprison", {"gl_prison", 140, 15}},
      {"Luoyang Dungeon", {"lou_dun03", 165, 38}},
      {"Hermit's Checkers", {"gon_dun02", 251, 263}},
      {"Izlude Dungeon", {"iz_dun02", 350, 335}},
      {"Turtle Island Dungeon", {"tur_dun02", 165, 30}},
      {"Clock Tower B3f", {"alde_dun03", 275, 180}},
      {"Clock Tower 3f", {"c_tower3", 34, 42}},
      {"Glast Heim Culvert 2f", {"gl_sew02", 292, 295}},
      {"Sphinx Dungeon 4f", {"in_sphinx4", 120, 120}},
      {"Inside Pyramid 4f", {"moc_pryd04", 195, 4}},
      {"Prontera Culvert 3f", {"prt_sewb3", 20, 175}},
      {"Amatsu Dungeon 1f (Tatami Maze)", {"ama_dun01", 222, 144}},
      {"Somatology Laboratory 1st floor", {"lhz_dun01", 19, 153}},
      {"Ayothya Ancient Shrine 2nd floor", {"ayo_dun02", 70, 240}}
    ]
  end

  defp destinations(2) do
    [
      {"Thor Volcano 2f", {"thor_v02", 77, 208}},
      {"Ice Dungeon Entrance", {"ra_fild01", 237, 333}},
      {"Nameless Island Entrance", {"ve_fild07", 127, 131}},
      {"Niflheim", {"niflheim", 206, 179}},
      {"Labyrinth Forest 2f", {"prt_maze02", 100, 174}},
      {"Ruins of Juperos Entrance", {"jupe_cave", 36, 54}},
      {"Ant Hell 2f", {"anthell02", 36, 265}},
      {"Kiel Hyre's Academy Entrance", {"yuno_fild08", 70, 171}},
      {"Thanatos Tower Entrance", {"hu_fild01", 140, 160}},
      {"Abyss Lake Entrance", {"hu_fild05", 168, 302}},
      {"Rachel Sanctuary Entrance", {"ra_temple", 117, 173}},
      {"Odin Temple 2f", {"odin_tem02", 257, 374}}
    ]
  end

  defp destinations(3) do
    [
      {"Bio Lab (2nd Floor)", {"lhz_dun02", 145, 149}},
      {"Ice Dungeon (3rd Floor)", {"ice_dun03", 150, 176}},
      {"Odin Temple (3rd Floor)", {"odin_tem03", 278, 235}},
      {"Thor Volcano (3rd Floor)", {"thor_v03", 144, 170}},
      {"Abyss Lake (3rd Floor)", {"abyss_03", 97, 104}},
      {"Juperos Ruins (2nd Floor)", {"juperos_02", 130, 159}}
    ]
  end

  defp destinations(_type), do: []
end
