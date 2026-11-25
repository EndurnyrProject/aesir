defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.SuspiciousGuy164127 do
  @moduledoc """
  A pickpocket steals from passersby and offers tonics when caught.

  ## Behavior

  - Attempts to steal zeny when a player approaches.
  - Offers up to three tonics for sale before moving to another location.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 164,
        y: 127,
        dir: 4,
        sprite: 870,
        name: "Suspicious Guy",
        scope: :shared,
        unique_name: "Suspicious Guy#lhz_03",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx), do: ctx

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Suspicious Guy#lhz_03")

  def on_event("OnTouch_", ctx) do
    case Enum.random(1..5) do
      n when n in [1, 2] -> steal(ctx, 100) |> unnoticed()
      n when n in [3, 4] -> steal(ctx, 200) |> suspicious()
      5 -> steal(ctx, 10) |> caught()
      _ -> ctx
    end
  end

  defp steal(ctx, amount) do
    ctx = ctx |> mes("^3355FF*SHHHHHHUK!*^000000") |> specialeffect(:steal)
    ctx = if zeny(ctx) >= amount, do: pay_zeny(ctx, amount), else: ctx

    ctx
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Huh...?")
  end

  defp unnoticed(ctx) do
    ctx
    |> mes("I sense something...")
    |> mes("No. It might just")
    |> mes("be my imagination.")
    |> next()
    |> mes("[?????]")
    |> mes("^333333Heh heh heh heh...^000000")
    |> close()
  end

  defp suspicious(ctx) do
    ctx
    |> mes("I could have sworn")
    |> mes("that these pockets full")
    |> mes("of zeny were heavier")
    |> mes("just a second ago...")
    |> next()
    |> mes("[?????]")
    |> mes("^333333Heh heh heh heh...^000000")
    |> close()
  end

  defp caught(ctx) do
    ctx =
      ctx
      |> mes("What the?!")
      |> mes("That guy, did he just...?")
      |> mes("He did! Hey! That guy")
      |> mes("stole some of my money!")
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("Oh crap!")
      |> mes("Gotta scram!")
      |> mes("Eat my dust, good gu--!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Oh no, you don't!")
      |> mes("I'm turning you in,")
      |> mes("you pickpocket!")
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("No...! I'm sorry!")
      |> mes("I'll give you back")
      |> mes("your money, just ")
      |> mes("let me go! Crap!")
      |> emotion(:cry)
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Alright, fine,")
      |> mes("but you better quit")
      |> mes("this life of crime!")
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("You're right, that was")
      |> mes("wrong of me. Thanks")
      |> mes("for letting me go. Since")
      |> mes("you did me a favor, I'll")
      |> mes("sell you some tonic that")
      |> mes("I use to run really fast.")
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("I can only sell up to")
      |> mes("three of my secret tonic")
      |> mes("to you since that's all")
      |> mes("I have. Each one will")
      |> mes("cost 15,000 zeny. So")
      |> mes("what do you say?")
      |> next()
      |> select(["Give me 1.", "Give me 2.", "Give me 3.", "No, I'm fine."])

    case choice do
      number when number in 1..3 ->
        ctx
        |> set_local(:number, number)
        |> set_local(:price, 15_000 * number)
        |> finish_sale()

      4 ->
        ctx
        |> mes("[Suspicious Guy]")
        |> mes("Well...")
        |> mes("You're just gonna")
        |> mes("let me go, then?")
        |> mes("That's awful generous.")
        |> mes("Thanks, I appreciate it.")
        |> next()
        |> back_to_work()
        |> finish_sale()

      _ ->
        ctx
    end
  end

  defp finish_sale(ctx) do
    ctx =
      if Rathena.truthy?(get_local(ctx, :number, 0)) do
        sell_tonic(ctx)
      else
        ctx
      end

    ctx =
      if Enum.random(1..2) == 1 do
        ctx |> enablenpc("Suspicious Guy#lhz_01") |> disablenpc("Suspicious Guy#lhz_03")
      else
        ctx |> enablenpc("Suspicious Guy#lhz_02") |> disablenpc("Suspicious Guy#lhz_03")
      end

    close(ctx)
  end

  defp sell_tonic(ctx) do
    cond do
      zeny(ctx) < get_local(ctx, :price, 0) ->
        ctx
        |> mes("[Suspicious Guy]")
        |> mes("Er, since I'm quitting")
        |> mes("pickpocketing, I need")
        |> mes("to make cash legitimately")
        |> mes("as a business person. I'm")
        |> mes("real sorry pal, but I can't just")
        |> mes("give these tonics away!")
        |> next()
        |> back_to_work()

      max_weight(ctx) - weight(ctx) < 400 ->
        ctx
        |> mes("[Suspicious Guy]")
        |> mes("Eh, I'm sorry, but you")
        |> mes("don't have enough room")
        |> mes("in your inventory to even")
        |> mes("hold these tonics. Sorry")
        |> mes("pal, but this deal's off.")
        |> next()
        |> back_to_work()

      true ->
        ctx = mes(ctx, "[Suspicious Guy]")
        ctx = sale_dialogue(ctx, get_local(ctx, :number, 0))
        ctx = pay_zeny(ctx, get_local(ctx, :price, 0))
        give_item(ctx, 12_016, get_local(ctx, :number, 0))
    end
  end

  defp back_to_work(ctx) do
    ctx
    |> mes("[Suspicious Guy]")
    |> mes("Anyway, I'm gonna")
    |> mes("get back to work.")
    |> mes("Heh heh heh~")
  end

  defp sale_dialogue(ctx, 1) do
    ctx
    |> mes("Only one? Alright, you")
    |> mes("might be a cheapskate,")
    |> mes("but I do owe you. Just")
    |> mes("take this and I hope we never")
    |> mes("bump into each other again!")
  end

  defp sale_dialogue(ctx, 2) do
    ctx
    |> mes("Two, huh? I can dig it.")
    |> mes("Now take these and I hope")
    |> mes("we never see each other")
    |> mes("ever again! Ciao, baby~")
  end

  defp sale_dialogue(ctx, _) do
    ctx
    |> mes("You want all three?")
    |> mes("Heh, you're much smarter")
    |> mes("than I thought! Alright, take")
    |> mes("these with my compliments,")
    |> mes("but I hope we never bump")
    |> mes("into each other ever again!")
  end
end
