defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Tensue do
  @moduledoc """
  Shares one of TenSue's observations about guilds, travel, or Rune-Midgarts.

  ## Behavior

  - Randomly discusses joining a guild, traveling to Al de Baran, or King Tristram III.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 177,
        y: 20,
        dir: 2,
        sprite: 97,
        name: "TenSue",
        scope: :shared,
        unique_name: "TenSue#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case :rand.uniform(3) - 1 do
      1 -> discuss_guilds(ctx)
      2 -> discuss_al_de_baran(ctx)
      _ -> discuss_king(ctx)
    end
  end

  defp discuss_guilds(ctx) do
    ctx
    |> mes("[TenSue]")
    |> mes("What...?")
    |> mes("Sick and tired of killing monsters on fields and in dungeons already? Come on...")
    |> next()
    |> mes("[TenSue]")
    |> mes(
      "Hahaha, it seems you're pretty confident of your strength, huh? Hmm... Why don't you go join a guild? I mean, all the tough guys are going it."
    )
    |> next()
    |> mes("[TenSue]")
    |> mes(
      "Personally though, I don't know any guilds, so you'll have to ask around. Make some contacts, connections, you know, networking."
    )
    |> next()
    |> mes("[TenSue]")
    |> mes(
      "I don't even know if you don't like taking orders, but if that's the case, why don't you make your own guild?"
    )
    |> close()
  end

  defp discuss_al_de_baran(ctx) do
    ctx
    |> mes("[TenSue]")
    |> mes(
      "One time I walked all the way to Al de Baran, instead of taking a warp. It was pretty dangerous with all those monsters!"
    )
    |> next()
    |> mes("[TenSue]")
    |> mes(
      "I almost died! Some of those monsters just kept following me and trying to kill me, even though I did nothing to them! It was pretty crazy."
    )
    |> next()
    |> mes("[TenSue]")
    |> mes(
      "Well, still, I feel that taking the scenic route was worth it. There were some pretty magnificent sights on the way."
    )
    |> next()
    |> mes("[TenSue]")
    |> mes(
      "Even the city of Al de Baran is a splendid vision to the eyes, with its elegant architecture and romantic canal."
    )
    |> next()
    |> mes("[TenSue]")
    |> mes(
      "The headquarters of Kafra Corporation is also located in Al de Baran. You should really stop by and check it out for yourself."
    )
    |> close()
  end

  defp discuss_king(ctx) do
    ctx
    |> mes("[TenSue]")
    |> mes("The kingdom of")
    |> mes("Rune-Midgarts is ruled")
    |> mes("by kind and benevolent")
    |> mes("King Tristram III.")
    |> next()
    |> mes("[TenSue]")
    |> mes(
      "We really owe the prosperity of Rune-Midgarts to him. He was able to convince the people to welcome outsiders into Prontera, as well as establish trade to foreign lands, like Amatsu and Kunlun."
    )
    |> next()
    |> mes("[TenSue]")
    |> mes("But sometimes...")
    |> mes("It can be hard to believe he's such a brilliant and capable leader.")
    |> next()
    |> mes("[TenSue]")
    |> mes(
      "After all, the only time I see him is when he's conducting weddings. Even if a wedding isn't going on, he's still kind of loitering around the Prontera church!"
    )
    |> next()
    |> mes("[TenSue]")
    |> mes("But...")
    |> mes(
      "I guess you can get away with a lot of things when you happen to be lord and ruler of an entire nation."
    )
    |> close()
  end
end
