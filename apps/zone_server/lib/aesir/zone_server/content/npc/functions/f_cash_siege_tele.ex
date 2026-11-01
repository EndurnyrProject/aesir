defmodule Aesir.ZoneServer.Content.Npc.Functions.FCashSiegeTele do
  @moduledoc """
  Offers the twenty castle approaches for the siege teleport scroll.

  ## Behavior

  Selection warps to the castle's approach cell and ends the calling script.
  The menu and coordinates are identical in both game modes.

  ## Credits

  Original function by L0ne_W0lf, with teleport-function updates by Euphy.

  ## Adaptation

  LLM-assisted Elixir port of the shared Cash Shop function.
  """

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl

  @doc "Runs the siege destination menu."
  @spec call(Ctx.t(), [integer()]) :: no_return()
  def call(ctx, _args) do
    entries = [
      {"Neuschwanstein (aldeg_cas01)", {"alde_gld", 48, 91}},
      {"Hohenschwangau (aldeg_cas02)", {"alde_gld", 103, 245}},
      {"Nuernberg (aldeg_cas03)", {"alde_gld", 142, 87}},
      {"Wuerzburg (aldeg_cas04)", {"alde_gld", 236, 243}},
      {"Rothenburg (aldeg_cas05)", {"alde_gld", 269, 90}},
      {"Repherion (gefg_cas01)", {"gef_fild13", 217, 75}},
      {"Eeyorbriggar (gefg_cas02)", {"gef_fild13", 307, 237}},
      {"Yesnelph (gefg_cas03)", {"gef_fild13", 77, 297}},
      {"Bergel (gefg_cas04)", {"gef_fild13", 190, 276}},
      {"Mersetzdeitz (gefg_cas05)", {"gef_fild13", 312, 91}},
      {"Bright Arbor (payg_cas01)", {"pay_gld", 121, 232}},
      {"Sacred Altar (payg_cas02)", {"pay_gld", 297, 116}},
      {"Holy Shadow (payg_cas03)", {"pay_gld", 318, 293}},
      {"Scarlet Palace (payg_cas04)", {"pay_gld", 140, 164}},
      {"Bamboo Grove Hill (payg_cas05)", {"pay_gld", 202, 264}},
      {"Kriemhild (prtg_cas01)", {"prt_gld", 141, 64}},
      {"Swanhild (prtg_cas02)", {"prt_gld", 240, 131}},
      {"Fadhgridh (prtg_cas03)", {"prt_gld", 153, 133}},
      {"Skoegul (prtg_cas04)", {"prt_gld", 126, 240}},
      {"Gondul (prtg_cas05)", {"prt_gld", 195, 240}}
    ]

    {ctx, choice} = Dsl.select(ctx, Enum.map(entries, &elem(&1, 0)))
    {_label, {map, x, y}} = Enum.at(entries, choice - 1)
    ctx = Dsl.warp(ctx, map, x, y)
    throw({:script_end, ctx})
  end
end
