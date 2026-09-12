defmodule Aesir.ZoneServer.Content.Npc.Woe.InsideFlag do
  @moduledoc """
  Guild flag inside a castle interior or its town: shows the owning guild's
  emblem through `guild_id/1` but carries no dialog of its own, unlike the
  outside flags on the guild field maps.
  """

  use Aesir.ZoneServer.Npc,
    spawn: [
      %{
        map: "aldeg_cas01",
        x: 30,
        y: 248,
        dir: 4,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in0"
      },
      %{
        map: "aldeg_cas01",
        x: 30,
        y: 248,
        dir: 4,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in1"
      },
      %{
        map: "aldeg_cas01",
        x: 37,
        y: 248,
        dir: 4,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in2"
      },
      %{
        map: "aldeg_cas01",
        x: 37,
        y: 246,
        dir: 4,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in3"
      },
      %{
        map: "aldeg_cas01",
        x: 30,
        y: 246,
        dir: 4,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in4"
      },
      %{
        map: "aldeg_cas01",
        x: 95,
        y: 80,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in5"
      },
      %{
        map: "aldeg_cas01",
        x: 95,
        y: 59,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in6"
      },
      %{
        map: "aldeg_cas01",
        x: 62,
        y: 75,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in7"
      },
      %{
        map: "aldeg_cas01",
        x: 66,
        y: 75,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in8"
      },
      %{
        map: "aldeg_cas01",
        x: 70,
        y: 75,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in9"
      },
      %{
        map: "aldeg_cas01",
        x: 74,
        y: 75,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in10"
      },
      %{
        map: "aldeg_cas01",
        x: 62,
        y: 64,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in11"
      },
      %{
        map: "aldeg_cas01",
        x: 66,
        y: 64,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in12"
      },
      %{
        map: "aldeg_cas01",
        x: 70,
        y: 64,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in13"
      },
      %{
        map: "aldeg_cas01",
        x: 74,
        y: 64,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in14"
      },
      %{
        map: "aldeg_cas01",
        x: 74,
        y: 64,
        dir: 2,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in15"
      },
      %{
        map: "aldeg_cas01",
        x: 203,
        y: 150,
        dir: 4,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in16"
      },
      %{
        map: "aldeg_cas01",
        x: 210,
        y: 150,
        dir: 4,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in17"
      },
      %{
        map: "aldebaran",
        x: 152,
        y: 97,
        dir: 4,
        sprite: 722,
        name: "Neuschwanstein",
        unique_name: "Neuschwanstein#aldeg_cas01#in18"
      },
      %{
        map: "aldeg_cas02",
        x: 82,
        y: 71,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in0"
      },
      %{
        map: "aldeg_cas02",
        x: 67,
        y: 30,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in1"
      },
      %{
        map: "aldeg_cas02",
        x: 183,
        y: 140,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in2"
      },
      %{
        map: "aldeg_cas02",
        x: 212,
        y: 152,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in3"
      },
      %{
        map: "aldeg_cas02",
        x: 108,
        y: 39,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in4"
      },
      %{
        map: "aldeg_cas02",
        x: 57,
        y: 213,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in5"
      },
      %{
        map: "aldeg_cas02",
        x: 103,
        y: 53,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in6"
      },
      %{
        map: "aldeg_cas02",
        x: 73,
        y: 53,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in7"
      },
      %{
        map: "aldeg_cas02",
        x: 63,
        y: 41,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in8"
      },
      %{
        map: "aldeg_cas02",
        x: 229,
        y: 6,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in9"
      },
      %{
        map: "aldeg_cas02",
        x: 230,
        y: 40,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in10"
      },
      %{
        map: "aldeg_cas02",
        x: 197,
        y: 40,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in11"
      },
      %{
        map: "aldeg_cas02",
        x: 32,
        y: 213,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in12"
      },
      %{
        map: "aldeg_cas02",
        x: 121,
        y: 29,
        dir: 2,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in13"
      },
      %{
        map: "aldebaran",
        x: 149,
        y: 97,
        dir: 4,
        sprite: 722,
        name: "Hohenschwangau",
        unique_name: "Hohenschwangau#aldeg_cas02#in14"
      },
      %{
        map: "aldeg_cas03",
        x: 176,
        y: 175,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in0"
      },
      %{
        map: "aldeg_cas03",
        x: 77,
        y: 115,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in1"
      },
      %{
        map: "aldeg_cas03",
        x: 77,
        y: 215,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in2"
      },
      %{
        map: "aldeg_cas03",
        x: 112,
        y: 107,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in3"
      },
      %{
        map: "aldeg_cas03",
        x: 112,
        y: 117,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in4"
      },
      %{
        map: "aldeg_cas03",
        x: 69,
        y: 71,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in5"
      },
      %{
        map: "aldeg_cas03",
        x: 91,
        y: 69,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in6"
      },
      %{
        map: "aldeg_cas03",
        x: 108,
        y: 60,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in7"
      },
      %{
        map: "aldeg_cas03",
        x: 121,
        y: 73,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in8"
      },
      %{
        map: "aldeg_cas03",
        x: 121,
        y: 73,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in9"
      },
      %{
        map: "aldeg_cas03",
        x: 75,
        y: 102,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in10"
      },
      %{
        map: "aldeg_cas03",
        x: 199,
        y: 169,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in11"
      },
      %{
        map: "aldeg_cas03",
        x: 181,
        y: 179,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in12"
      },
      %{
        map: "aldeg_cas03",
        x: 192,
        y: 44,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in13"
      },
      %{
        map: "aldeg_cas03",
        x: 208,
        y: 145,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in14"
      },
      %{
        map: "aldeg_cas03",
        x: 207,
        y: 75,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in15"
      },
      %{
        map: "aldeg_cas03",
        x: 96,
        y: 62,
        dir: 2,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in16"
      },
      %{
        map: "aldebaran",
        x: 134,
        y: 97,
        dir: 4,
        sprite: 722,
        name: "Nuernberg",
        unique_name: "Nuernberg#aldeg_cas03#in17"
      },
      %{
        map: "aldeg_cas04",
        x: 167,
        y: 61,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in0"
      },
      %{
        map: "aldeg_cas04",
        x: 164,
        y: 90,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in1"
      },
      %{
        map: "aldeg_cas04",
        x: 129,
        y: 193,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in2"
      },
      %{
        map: "aldeg_cas04",
        x: 112,
        y: 206,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in3"
      },
      %{
        map: "aldeg_cas04",
        x: 113,
        y: 212,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in4"
      },
      %{
        map: "aldeg_cas04",
        x: 77,
        y: 117,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in5"
      },
      %{
        map: "aldeg_cas04",
        x: 186,
        y: 42,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in6"
      },
      %{
        map: "aldeg_cas04",
        x: 30,
        y: 69,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in7"
      },
      %{
        map: "aldeg_cas04",
        x: 55,
        y: 97,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in8"
      },
      %{
        map: "aldeg_cas04",
        x: 45,
        y: 98,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in9"
      },
      %{
        map: "aldeg_cas04",
        x: 33,
        y: 116,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in10"
      },
      %{
        map: "aldeg_cas04",
        x: 130,
        y: 180,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in11"
      },
      %{
        map: "aldeg_cas04",
        x: 129,
        y: 193,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in12"
      },
      %{
        map: "aldeg_cas04",
        x: 33,
        y: 107,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in13"
      },
      %{
        map: "aldeg_cas04",
        x: 133,
        y: 220,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in14"
      },
      %{
        map: "aldeg_cas04",
        x: 169,
        y: 22,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in15"
      },
      %{
        map: "aldeg_cas04",
        x: 169,
        y: 15,
        dir: 2,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in16"
      },
      %{
        map: "aldebaran",
        x: 131,
        y: 97,
        dir: 4,
        sprite: 722,
        name: "Wuerzburg",
        unique_name: "Wuerzburg#aldeg_cas04#in17"
      },
      %{
        map: "aldeg_cas05",
        x: 170,
        y: 85,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in0"
      },
      %{
        map: "aldeg_cas05",
        x: 142,
        y: 212,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in1"
      },
      %{
        map: "aldeg_cas05",
        x: 149,
        y: 196,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in2"
      },
      %{
        map: "aldeg_cas05",
        x: 41,
        y: 180,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in3"
      },
      %{
        map: "aldeg_cas05",
        x: 38,
        y: 201,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in4"
      },
      %{
        map: "aldeg_cas05",
        x: 65,
        y: 182,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in5"
      },
      %{
        map: "aldeg_cas05",
        x: 65,
        y: 205,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in6"
      },
      %{
        map: "aldeg_cas05",
        x: 10,
        y: 218,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in7"
      },
      %{
        map: "aldeg_cas05",
        x: 10,
        y: 218,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in8"
      },
      %{
        map: "aldeg_cas05",
        x: 164,
        y: 201,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in9"
      },
      %{
        map: "aldeg_cas05",
        x: 14,
        y: 117,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in10"
      },
      %{
        map: "aldeg_cas05",
        x: 10,
        y: 225,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in11"
      },
      %{
        map: "aldeg_cas05",
        x: 187,
        y: 59,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in12"
      },
      %{
        map: "aldeg_cas05",
        x: 154,
        y: 51,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in13"
      },
      %{
        map: "aldeg_cas05",
        x: 22,
        y: 211,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in14"
      },
      %{
        map: "aldeg_cas05",
        x: 150,
        y: 202,
        dir: 2,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in15"
      },
      %{
        map: "aldebaran",
        x: 128,
        y: 97,
        dir: 4,
        sprite: 722,
        name: "Rothenburg",
        unique_name: "Rothenburg#aldeg_cas05#in16"
      },
      %{
        map: "gefg_cas01",
        x: 28,
        y: 157,
        dir: 4,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#in0"
      },
      %{
        map: "gefg_cas01",
        x: 22,
        y: 156,
        dir: 5,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#in1"
      },
      %{
        map: "gefg_cas01",
        x: 68,
        y: 185,
        dir: 3,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#in2"
      },
      %{
        map: "gefg_cas01",
        x: 17,
        y: 171,
        dir: 5,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#in3"
      },
      %{
        map: "gefg_cas01",
        x: 59,
        y: 16,
        dir: 4,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#in4"
      },
      %{
        map: "gefg_cas01",
        x: 64,
        y: 16,
        dir: 4,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#in5"
      },
      %{
        map: "geffen",
        x: 109,
        y: 123,
        dir: 2,
        sprite: 722,
        name: "Repherion",
        unique_name: "Repherion#gefg_cas01#in6"
      },
      %{
        map: "gefg_cas02",
        x: 65,
        y: 130,
        dir: 5,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#in0"
      },
      %{
        map: "gefg_cas02",
        x: 30,
        y: 123,
        dir: 5,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#in1"
      },
      %{
        map: "gefg_cas02",
        x: 65,
        y: 139,
        dir: 6,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#in2"
      },
      %{
        map: "gefg_cas02",
        x: 37,
        y: 177,
        dir: 6,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#in3"
      },
      %{
        map: "gefg_cas02",
        x: 37,
        y: 168,
        dir: 6,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#in4"
      },
      %{
        map: "gefg_cas02",
        x: 68,
        y: 47,
        dir: 2,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#in5"
      },
      %{
        map: "gefg_cas02",
        x: 68,
        y: 36,
        dir: 2,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#in6"
      },
      %{
        map: "geffen",
        x: 112,
        y: 129,
        dir: 1,
        sprite: 722,
        name: "Eeyolbriggar",
        unique_name: "Eeyolbriggar#gefg_cas02#in7"
      },
      %{
        map: "gefg_cas03",
        x: 122,
        y: 220,
        dir: 6,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#in0"
      },
      %{
        map: "gefg_cas03",
        x: 122,
        y: 229,
        dir: 6,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#in1"
      },
      %{
        map: "gefg_cas03",
        x: 91,
        y: 257,
        dir: 7,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#in2"
      },
      %{
        map: "gefg_cas03",
        x: 52,
        y: 276,
        dir: 7,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#in3"
      },
      %{
        map: "gefg_cas03",
        x: 56,
        y: 164,
        dir: 4,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#in4"
      },
      %{
        map: "gefg_cas03",
        x: 65,
        y: 164,
        dir: 4,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#in5"
      },
      %{
        map: "gefg_cas03",
        x: 37,
        y: 214,
        dir: 1,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#in6"
      },
      %{
        map: "gefg_cas03",
        x: 34,
        y: 208,
        dir: 1,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#in7"
      },
      %{
        map: "geffen",
        x: 120,
        y: 132,
        dir: 8,
        sprite: 722,
        name: "Yesnelph",
        unique_name: "Yesnelph#gefg_cas03#in8"
      },
      %{
        map: "gefg_cas04",
        x: 24,
        y: 157,
        dir: 4,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#in0"
      },
      %{
        map: "gefg_cas04",
        x: 35,
        y: 158,
        dir: 4,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#in1"
      },
      %{
        map: "gefg_cas04",
        x: 44,
        y: 184,
        dir: 4,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#in2"
      },
      %{
        map: "gefg_cas04",
        x: 51,
        y: 184,
        dir: 4,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#in3"
      },
      %{
        map: "gefg_cas04",
        x: 39,
        y: 212,
        dir: 7,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#in4"
      },
      %{
        map: "gefg_cas04",
        x: 29,
        y: 212,
        dir: 1,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#in5"
      },
      %{
        map: "gefg_cas04",
        x: 24,
        y: 73,
        dir: 1,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#in6"
      },
      %{
        map: "gefg_cas04",
        x: 35,
        y: 73,
        dir: 4,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#in7"
      },
      %{
        map: "geffen",
        x: 127,
        y: 130,
        dir: 7,
        sprite: 722,
        name: "Bergel",
        unique_name: "Bergel#gefg_cas04#in8"
      },
      %{
        map: "gefg_cas05",
        x: 77,
        y: 185,
        dir: 7,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#in0"
      },
      %{
        map: "gefg_cas05",
        x: 92,
        y: 181,
        dir: 0,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#in1"
      },
      %{
        map: "gefg_cas05",
        x: 83,
        y: 158,
        dir: 1,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#in2"
      },
      %{
        map: "gefg_cas05",
        x: 62,
        y: 144,
        dir: 7,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#in3"
      },
      %{
        map: "gefg_cas05",
        x: 62,
        y: 66,
        dir: 4,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#in4"
      },
      %{
        map: "gefg_cas05",
        x: 69,
        y: 66,
        dir: 4,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#in5"
      },
      %{
        map: "geffen",
        x: 131,
        y: 123,
        dir: 6,
        sprite: 722,
        name: "Mersetzdeitz",
        unique_name: "Mersetzdeitz#gefg_cas05#in6"
      },
      %{
        map: "payg_cas01",
        x: 238,
        y: 67,
        dir: 4,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#in0"
      },
      %{
        map: "payg_cas01",
        x: 233,
        y: 67,
        dir: 4,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#in1"
      },
      %{
        map: "payg_cas01",
        x: 221,
        y: 123,
        dir: 4,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#in2"
      },
      %{
        map: "payg_cas01",
        x: 221,
        y: 116,
        dir: 4,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#in3"
      },
      %{
        map: "payg_cas01",
        x: 206,
        y: 108,
        dir: 4,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#in4"
      },
      %{
        map: "payg_cas01",
        x: 212,
        y: 108,
        dir: 4,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#in5"
      },
      %{
        map: "payon",
        x: 90,
        y: 322,
        dir: 4,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#in6"
      },
      %{
        map: "payon",
        x: 166,
        y: 177,
        dir: 3,
        sprite: 722,
        name: "Bright Arbor",
        unique_name: "Bright Arbor#payg_cas01#in7"
      },
      %{
        map: "payg_cas02",
        x: 254,
        y: 40,
        dir: 6,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#in0"
      },
      %{
        map: "payg_cas02",
        x: 254,
        y: 48,
        dir: 6,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#in1"
      },
      %{
        map: "payg_cas02",
        x: 202,
        y: 49,
        dir: 0,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#in2"
      },
      %{
        map: "payg_cas02",
        x: 209,
        y: 49,
        dir: 0,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#in3"
      },
      %{
        map: "payg_cas02",
        x: 59,
        y: 282,
        dir: 4,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#in4"
      },
      %{
        map: "payg_cas02",
        x: 70,
        y: 282,
        dir: 4,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#in5"
      },
      %{
        map: "payon",
        x: 97,
        y: 322,
        dir: 4,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#in6"
      },
      %{
        map: "payon",
        x: 166,
        y: 173,
        dir: 3,
        sprite: 722,
        name: "Scarlet Palace",
        unique_name: "Scarlet Palace#payg_cas02#in7"
      },
      %{
        map: "payg_cas03",
        x: 236,
        y: 54,
        dir: 2,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#in0"
      },
      %{
        map: "payg_cas03",
        x: 236,
        y: 45,
        dir: 2,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#in1"
      },
      %{
        map: "payg_cas03",
        x: 259,
        y: 66,
        dir: 4,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#in2"
      },
      %{
        map: "payg_cas03",
        x: 266,
        y: 66,
        dir: 4,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#in3"
      },
      %{
        map: "payg_cas03",
        x: 34,
        y: 31,
        dir: 4,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#in4"
      },
      %{
        map: "payg_cas03",
        x: 43,
        y: 31,
        dir: 4,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#in5"
      },
      %{
        map: "payon",
        x: 113,
        y: 322,
        dir: 4,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#in6"
      },
      %{
        map: "payon",
        x: 166,
        y: 169,
        dir: 3,
        sprite: 722,
        name: "Holy Shadow",
        unique_name: "Holy Shadow#payg_cas03#in7"
      },
      %{
        map: "payg_cas04",
        x: 255,
        y: 259,
        dir: 0,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#in0"
      },
      %{
        map: "payg_cas04",
        x: 248,
        y: 259,
        dir: 0,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#in1"
      },
      %{
        map: "payg_cas04",
        x: 248,
        y: 168,
        dir: 6,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#in2"
      },
      %{
        map: "payg_cas04",
        x: 248,
        y: 160,
        dir: 6,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#in3"
      },
      %{
        map: "payg_cas04",
        x: 232,
        y: 181,
        dir: 4,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#in4"
      },
      %{
        map: "payg_cas04",
        x: 239,
        y: 181,
        dir: 4,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#in5"
      },
      %{
        map: "payon",
        x: 118,
        y: 322,
        dir: 4,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#in6"
      },
      %{
        map: "payon",
        x: 166,
        y: 165,
        dir: 3,
        sprite: 722,
        name: "Sacred Altar",
        unique_name: "Sacred Altar#payg_cas04#in7"
      },
      %{
        map: "payg_cas05",
        x: 32,
        y: 249,
        dir: 4,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#in0"
      },
      %{
        map: "payg_cas05",
        x: 24,
        y: 249,
        dir: 4,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#in1"
      },
      %{
        map: "payg_cas05",
        x: 62,
        y: 271,
        dir: 0,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#in2"
      },
      %{
        map: "payg_cas05",
        x: 57,
        y: 271,
        dir: 0,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#in3"
      },
      %{
        map: "payg_cas05",
        x: 55,
        y: 252,
        dir: 2,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#in4"
      },
      %{
        map: "payg_cas05",
        x: 55,
        y: 260,
        dir: 2,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#in5"
      },
      %{
        map: "payon",
        x: 123,
        y: 322,
        dir: 4,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#in6"
      },
      %{
        map: "payon",
        x: 166,
        y: 161,
        dir: 3,
        sprite: 722,
        name: "Bamboo Grove Hill",
        unique_name: "Bamboo Grove Hill#payg_cas05#in7"
      },
      %{
        map: "prtg_cas01",
        x: 58,
        y: 56,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in0"
      },
      %{
        map: "prtg_cas01",
        x: 64,
        y: 56,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in1"
      },
      %{
        map: "prtg_cas01",
        x: 76,
        y: 32,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in2"
      },
      %{
        map: "prtg_cas01",
        x: 84,
        y: 32,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in3"
      },
      %{
        map: "prtg_cas01",
        x: 94,
        y: 39,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in4"
      },
      %{
        map: "prtg_cas01",
        x: 94,
        y: 24,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in5"
      },
      %{
        map: "prtg_cas01",
        x: 73,
        y: 14,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in6"
      },
      %{
        map: "prtg_cas01",
        x: 73,
        y: 6,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in7"
      },
      %{
        map: "prtg_cas01",
        x: 55,
        y: 46,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in8"
      },
      %{
        map: "prtg_cas01",
        x: 45,
        y: 46,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in9"
      },
      %{
        map: "prontera",
        x: 155,
        y: 190,
        dir: 4,
        sprite: 722,
        name: "Kriemhild",
        unique_name: "Kriemhild#prtg_cas01#in10"
      },
      %{
        map: "prtg_cas02",
        x: 40,
        y: 227,
        dir: 4,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in0"
      },
      %{
        map: "prtg_cas02",
        x: 46,
        y: 227,
        dir: 4,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in1"
      },
      %{
        map: "prtg_cas02",
        x: 11,
        y: 219,
        dir: 4,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in2"
      },
      %{
        map: "prtg_cas02",
        x: 11,
        y: 214,
        dir: 4,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in3"
      },
      %{
        map: "prtg_cas02",
        x: 20,
        y: 219,
        dir: 4,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in4"
      },
      %{
        map: "prtg_cas02",
        x: 20,
        y: 214,
        dir: 4,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in5"
      },
      %{
        map: "prtg_cas02",
        x: 79,
        y: 227,
        dir: 8,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in6"
      },
      %{
        map: "prtg_cas02",
        x: 70,
        y: 227,
        dir: 8,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in7"
      },
      %{
        map: "prtg_cas02",
        x: 38,
        y: 189,
        dir: 8,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in8"
      },
      %{
        map: "prtg_cas02",
        x: 34,
        y: 189,
        dir: 8,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in9"
      },
      %{
        map: "prtg_cas02",
        x: 153,
        y: 161,
        dir: 4,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in10"
      },
      %{
        map: "prtg_cas02",
        x: 162,
        y: 161,
        dir: 4,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in11"
      },
      %{
        map: "prontera",
        x: 146,
        y: 194,
        dir: 3,
        sprite: 722,
        name: "Swanhild",
        unique_name: "Swanhild#prtg_cas02#in12"
      },
      %{
        map: "prtg_cas03",
        x: 168,
        y: 28,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in0"
      },
      %{
        map: "prtg_cas03",
        x: 182,
        y: 28,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in1"
      },
      %{
        map: "prtg_cas03",
        x: 43,
        y: 50,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in2"
      },
      %{
        map: "prtg_cas03",
        x: 48,
        y: 50,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in3"
      },
      %{
        map: "prtg_cas03",
        x: 43,
        y: 58,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in4"
      },
      %{
        map: "prtg_cas03",
        x: 48,
        y: 58,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in5"
      },
      %{
        map: "prtg_cas03",
        x: 158,
        y: 210,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in6"
      },
      %{
        map: "prtg_cas03",
        x: 169,
        y: 210,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in7"
      },
      %{
        map: "prtg_cas03",
        x: 162,
        y: 201,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in8"
      },
      %{
        map: "prtg_cas03",
        x: 165,
        y: 201,
        dir: 4,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in9"
      },
      %{
        map: "prontera",
        x: 143,
        y: 203,
        dir: 2,
        sprite: 722,
        name: "Fadhgridh",
        unique_name: "Fadhgridh#prtg_cas03#in10"
      },
      %{
        map: "prtg_cas04",
        x: 82,
        y: 29,
        dir: 4,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in0"
      },
      %{
        map: "prtg_cas04",
        x: 75,
        y: 29,
        dir: 4,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in1"
      },
      %{
        map: "prtg_cas04",
        x: 75,
        y: 27,
        dir: 4,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in2"
      },
      %{
        map: "prtg_cas04",
        x: 82,
        y: 27,
        dir: 4,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in3"
      },
      %{
        map: "prtg_cas04",
        x: 59,
        y: 29,
        dir: 4,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in4"
      },
      %{
        map: "prtg_cas04",
        x: 67,
        y: 29,
        dir: 4,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in5"
      },
      %{
        map: "prtg_cas04",
        x: 258,
        y: 25,
        dir: 4,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in6"
      },
      %{
        map: "prtg_cas04",
        x: 258,
        y: 20,
        dir: 4,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in7"
      },
      %{
        map: "prtg_cas04",
        x: 263,
        y: 20,
        dir: 4,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in8"
      },
      %{
        map: "prtg_cas04",
        x: 263,
        y: 27,
        dir: 4,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in9"
      },
      %{
        map: "prontera",
        x: 167,
        y: 203,
        dir: 6,
        sprite: 722,
        name: "Skoegul",
        unique_name: "Skoegul#prtg_cas04#in10"
      },
      %{
        map: "prtg_cas05",
        x: 19,
        y: 247,
        dir: 4,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#in0"
      },
      %{
        map: "prtg_cas05",
        x: 19,
        y: 243,
        dir: 4,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#in1"
      },
      %{
        map: "prtg_cas05",
        x: 26,
        y: 247,
        dir: 4,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#in2"
      },
      %{
        map: "prtg_cas05",
        x: 26,
        y: 243,
        dir: 4,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#in3"
      },
      %{
        map: "prtg_cas05",
        x: 249,
        y: 289,
        dir: 4,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#in4"
      },
      %{
        map: "prtg_cas05",
        x: 256,
        y: 289,
        dir: 4,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#in5"
      },
      %{
        map: "prtg_cas05",
        x: 253,
        y: 271,
        dir: 4,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#in6"
      },
      %{
        map: "prtg_cas05",
        x: 273,
        y: 257,
        dir: 4,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#in7"
      },
      %{
        map: "prontera",
        x: 165,
        y: 194,
        dir: 5,
        sprite: 722,
        name: "Gondul",
        unique_name: "Gondul#prtg_cas05#in8"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Woe.FlagOwner

  @impl true
  def guild_id(placement), do: FlagOwner.guild_id(placement)

  @impl true
  def on_talk(ctx), do: close(ctx)
end
