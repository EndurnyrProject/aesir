defmodule Aesir.ZoneServer.Content.Npc.Woe.OutsideFlag do
  @moduledoc """
  Guild flag on the shared guild field map outside a castle. Shows the
  castle's owner edict (or a neutral notice while unowned) and displays the
  owning guild's emblem through `guild_id/1`. An owner-guild member can also
  use it to warp straight to the castle's flag entry cell.

  The flag's own castle map is read from the hidden fragment of its
  `unique_name` (`strnpcinfo(ctx, 2)`), since the placement itself sits on
  the field map, not the castle.
  """

  use Aesir.ZoneServer.Npc,
    spawn: [
      %{
        map: "alde_gld",
        x: 61,
        y: 87,
        dir: 6,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#out0"
      },
      %{
        map: "alde_gld",
        x: 61,
        y: 79,
        dir: 6,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#out1"
      },
      %{
        map: "alde_gld",
        x: 45,
        y: 87,
        dir: 8,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#out2"
      },
      %{
        map: "alde_gld",
        x: 51,
        y: 87,
        dir: 8,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#out3"
      },
      %{
        map: "alde_gld",
        x: 99,
        y: 251,
        dir: 4,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#out0"
      },
      %{
        map: "alde_gld",
        x: 99,
        y: 244,
        dir: 4,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#out1"
      },
      %{
        map: "alde_gld",
        x: 146,
        y: 82,
        dir: 8,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#out0"
      },
      %{
        map: "alde_gld",
        x: 138,
        y: 82,
        dir: 8,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#out1"
      },
      %{
        map: "alde_gld",
        x: 239,
        y: 246,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#out0"
      },
      %{
        map: "alde_gld",
        x: 239,
        y: 239,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#out1"
      },
      %{
        map: "alde_gld",
        x: 265,
        y: 93,
        dir: 6,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#out0"
      },
      %{
        map: "alde_gld",
        x: 265,
        y: 87,
        dir: 6,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#out1"
      },
      %{
        map: "gef_fild13",
        x: 148,
        y: 51,
        dir: 5,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#out0"
      },
      %{
        map: "gef_fild13",
        x: 155,
        y: 54,
        dir: 5,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#out1"
      },
      %{
        map: "gef_fild13",
        x: 212,
        y: 79,
        dir: 6,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#out2"
      },
      %{
        map: "gef_fild13",
        x: 211,
        y: 71,
        dir: 6,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#out3"
      },
      %{
        map: "gef_fild13",
        x: 303,
        y: 243,
        dir: 4,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#out0"
      },
      %{
        map: "gef_fild13",
        x: 312,
        y: 243,
        dir: 4,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#out1"
      },
      %{
        map: "gef_fild13",
        x: 290,
        y: 243,
        dir: 4,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#out2"
      },
      %{
        map: "gef_fild13",
        x: 324,
        y: 243,
        dir: 4,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#out3"
      },
      %{
        map: "gef_fild13",
        x: 78,
        y: 182,
        dir: 4,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#out0"
      },
      %{
        map: "gef_fild13",
        x: 87,
        y: 182,
        dir: 4,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#out1"
      },
      %{
        map: "gef_fild13",
        x: 73,
        y: 295,
        dir: 7,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#out2"
      },
      %{
        map: "gef_fild13",
        x: 113,
        y: 274,
        dir: 7,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#out3"
      },
      %{
        map: "gef_fild13",
        x: 144,
        y: 235,
        dir: 6,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#out4"
      },
      %{
        map: "gef_fild13",
        x: 144,
        y: 244,
        dir: 6,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#out5"
      },
      %{
        map: "gef_fild13",
        x: 190,
        y: 283,
        dir: 3,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#out0"
      },
      %{
        map: "gef_fild13",
        x: 199,
        y: 274,
        dir: 3,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#out1"
      },
      %{
        map: "gef_fild13",
        x: 302,
        y: 87,
        dir: 7,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#out0"
      },
      %{
        map: "gef_fild13",
        x: 313,
        y: 83,
        dir: 0,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#out1"
      },
      %{
        map: "gef_fild13",
        x: 252,
        y: 51,
        dir: 2,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#out2"
      },
      %{
        map: "gef_fild13",
        x: 26,
        y: 147,
        dir: 2,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#out3"
      },
      %{
        map: "pay_gld",
        x: 125,
        y: 236,
        dir: 4,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#out0"
      },
      %{
        map: "pay_gld",
        x: 110,
        y: 233,
        dir: 4,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#out1"
      },
      %{
        map: "pay_gld",
        x: 116,
        y: 233,
        dir: 4,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#out2"
      },
      %{
        map: "pay_gld",
        x: 91,
        y: 239,
        dir: 2,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#out3"
      },
      %{
        map: "pay_gld",
        x: 292,
        y: 112,
        dir: 6,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#out0"
      },
      %{
        map: "pay_gld",
        x: 292,
        y: 120,
        dir: 6,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#out1"
      },
      %{
        map: "pay_gld",
        x: 291,
        y: 135,
        dir: 6,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#out2"
      },
      %{
        map: "pay_gld",
        x: 271,
        y: 163,
        dir: 0,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#out3"
      },
      %{
        map: "pay_gld",
        x: 321,
        y: 298,
        dir: 2,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#out0"
      },
      %{
        map: "pay_gld",
        x: 321,
        y: 289,
        dir: 2,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#out1"
      },
      %{
        map: "pay_gld",
        x: 327,
        y: 304,
        dir: 1,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#out2"
      },
      %{
        map: "pay_gld",
        x: 333,
        y: 254,
        dir: 4,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#out3"
      },
      %{
        map: "pay_gld",
        x: 137,
        y: 160,
        dir: 0,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#out0"
      },
      %{
        map: "pay_gld",
        x: 143,
        y: 160,
        dir: 0,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#out1"
      },
      %{
        map: "pay_gld",
        x: 133,
        y: 151,
        dir: 2,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#out2"
      },
      %{
        map: "pay_gld",
        x: 153,
        y: 166,
        dir: 1,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#out3"
      },
      %{
        map: "pay_gld",
        x: 208,
        y: 268,
        dir: 4,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#out0"
      },
      %{
        map: "pay_gld",
        x: 199,
        y: 268,
        dir: 4,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#out1"
      },
      %{
        map: "pay_gld",
        x: 190,
        y: 277,
        dir: 3,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#out2"
      },
      %{
        map: "pay_gld",
        x: 187,
        y: 294,
        dir: 2,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#out3"
      },
      %{
        map: "prt_gld",
        x: 131,
        y: 60,
        dir: 6,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#out0"
      },
      %{
        map: "prt_gld",
        x: 138,
        y: 68,
        dir: 6,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#out1"
      },
      %{
        map: "prt_gld",
        x: 138,
        y: 60,
        dir: 6,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#out2"
      },
      %{
        map: "prt_gld",
        x: 135,
        y: 60,
        dir: 6,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#out3"
      },
      %{
        map: "prt_gld",
        x: 244,
        y: 126,
        dir: 8,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#out0"
      },
      %{
        map: "prt_gld",
        x: 244,
        y: 128,
        dir: 8,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#out1"
      },
      %{
        map: "prt_gld",
        x: 236,
        y: 126,
        dir: 8,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#out2"
      },
      %{
        map: "prt_gld",
        x: 236,
        y: 128,
        dir: 8,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#out3"
      },
      %{
        map: "prt_gld",
        x: 147,
        y: 140,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#out0"
      },
      %{
        map: "prt_gld",
        x: 147,
        y: 136,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#out1"
      },
      %{
        map: "prt_gld",
        x: 158,
        y: 140,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#out2"
      },
      %{
        map: "prt_gld",
        x: 158,
        y: 136,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#out3"
      },
      %{
        map: "prt_gld",
        x: 120,
        y: 243,
        dir: 6,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#out0"
      },
      %{
        map: "prt_gld",
        x: 120,
        y: 236,
        dir: 6,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#out1"
      },
      %{
        map: "prt_gld",
        x: 122,
        y: 243,
        dir: 6,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#out2"
      },
      %{
        map: "prt_gld",
        x: 122,
        y: 236,
        dir: 6,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#out3"
      },
      %{
        map: "prt_gld",
        x: 199,
        y: 243,
        dir: 2,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#out0"
      },
      %{
        map: "prt_gld",
        x: 199,
        y: 236,
        dir: 2,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#out1"
      },
      %{
        map: "prt_gld",
        x: 197,
        y: 243,
        dir: 2,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#out2"
      },
      %{
        map: "prt_gld",
        x: 197,
        y: 236,
        dir: 2,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#out3"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Woe.FlagOwner
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb

  @entries %{
    "aldeg_cas01" => {218, 170},
    "aldeg_cas02" => {220, 190},
    "aldeg_cas03" => {205, 186},
    "aldeg_cas04" => {116, 217},
    "aldeg_cas05" => {167, 225},
    "gefg_cas01" => {197, 36},
    "gefg_cas02" => {178, 43},
    "gefg_cas03" => {221, 30},
    "gefg_cas04" => {168, 43},
    "gefg_cas05" => {168, 31},
    "payg_cas01" => {54, 144},
    "payg_cas02" => {278, 251},
    "payg_cas03" => {9, 263},
    "payg_cas04" => {40, 235},
    "payg_cas05" => {243, 27},
    "prtg_cas01" => {96, 173},
    "prtg_cas02" => {169, 55},
    "prtg_cas03" => {181, 215},
    "prtg_cas04" => {258, 247},
    "prtg_cas05" => {52, 41}
  }

  @impl true
  def guild_id(placement), do: FlagOwner.guild_id(placement)

  @impl true
  def on_talk(ctx) do
    map = ctx |> strnpcinfo(2) |> String.split("#") |> hd()

    case CastleDb.by_map(map) do
      {:ok, castle} -> handle_castle(ctx, castle.id, map)
      :error -> close(ctx)
    end
  end

  defp handle_castle(ctx, castle_id, map) do
    case castle_owner(ctx, castle_id) do
      nil -> unowned_edict(ctx)
      owner -> owned(ctx, owner, castle_id, map)
    end
  end

  defp owned(ctx, owner, castle_id, map) do
    if getcharid(ctx, 2) == owner do
      member_prompt(ctx, owner, castle_id, map)
    else
      owned_edict(ctx, owner)
    end
  end

  defp member_prompt(ctx, owner, castle_id, map) do
    {ctx, choice} =
      ctx
      |> mes("[Echoing Voice]")
      |> mes("Brave ones...")
      |> mes("Do you wish to return to your honorable place?")
      |> next()
      |> select(["Return to the guild castle.", "Quit."])

    handle_choice(ctx, choice, owner, castle_id, map)
  end

  defp handle_choice(ctx, 1, _owner, castle_id, map) do
    if castle_owner(ctx, castle_id) == getcharid(ctx, 2) do
      {x, y} = Map.fetch!(@entries, map)
      ctx |> close() |> warp(map, x, y)
    else
      close(ctx)
    end
  end

  defp handle_choice(ctx, _decline, _owner, _castle_id, _map), do: close(ctx)

  defp unowned_edict(ctx) do
    ctx
    |> mes("[Edict of the Divine Rune-Midgarts Kingdom]")
    |> mes(" ")
    |> mes("1. Follow the ordinance of The Divine Rune-Midgarts Kingdom,")
    |> mes("We declare that")
    |> mes("there is no formal master of this castle.")
    |> mes(" ")
    |> mes("2. To the one who can")
    |> mes("overcome all trials")
    |> mes("and destroy the Emperium,")
    |> mes("the king will endow the one with")
    |> mes("ownership of this castle.")
    |> close()
  end

  defp owned_edict(ctx, owner) do
    guild_name = getguildname(ctx, owner)
    master = getguildmaster(ctx, owner)

    ctx
    |> mes("[Edict of the Divine Rune-Midgarts Kingdom]")
    |> mes(" ")
    |> mes("1. Follow the ordinance of The Divine Rune-Midgarts Kingdom,")
    |> mes("we approve that this place is in")
    |> mes("the private prossession of ^ff0000#{guild_name}^000000 Guild.")
    |> mes(" ")
    |> mes("2. The guild Master of ^ff0000#{guild_name}^000000 Guild is")
    |> mes("^ff0000#{master}^000000")
    |> mes("If there is anyone who objects to this,")
    |> mes("prove your strength and honor with a steel blade in your hand.")
    |> close()
  end
end
