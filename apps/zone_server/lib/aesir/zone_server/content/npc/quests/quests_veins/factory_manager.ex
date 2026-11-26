defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.FactoryManager do
  @moduledoc """
  Mirhen supervises the stone factory.

  ## Behavior

  - Directs a stone delivery to the factory worker during Zabaroo's quest.
  - Sends other early quest visitors out of the factory.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in02",
        x: 37,
        y: 28,
        dir: 4,
        sprite: 898,
        name: "Factory Manager",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :veins_stone, 0)

    cond do
      Rathena.truthy?(progress) and progress < 5 ->
        ctx
        |> mes("[Mirhen]")
        |> mes("Hey, employees only beyond this point!")
        |> mes("Geez, don't we have a sigh that says that?")
        |> mes("We should get one...")
        |> mes("Anyway, get out of here.")
        |> close2()
        |> warp("veins", 269, 221)

      progress == 5 ->
        accept_delivery(ctx)

      true ->
        ctx
        |> mes("[Mirhen]")
        |> mes("Hetarium ...")
        |> mes("What's so special about")
        |> mes("it? I mean, it looks just like")
        |> mes("Iron Ore. Why the hell is")
        |> mes("it like classified info?")
        |> next()
        |> mes("[Mirhen]")
        |> mes("I wish I could return to")
        |> mes("Rekenber Headquarters...")
        |> mes("I hate being stuck here")
        |> mes("gathering silly rocks in")
        |> mes("the middle of nowhere.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp accept_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mirhen]")
      |> mes("Hey, employees only")
      |> mes("beyond this point!")
      |> mes("Geez, don't we have")
      |> mes("a sign that says that?")
      |> mes("We should get one...")
      |> mes("Anyway, get out of here.")
      |> next()
      |> select(["I'm sorry.", "I've brought these..."])

    if choice == 1 do
      ctx
      |> mes("[Mirhen]")
      |> mes("You're sorry,")
      |> mes("I get it. Ummm...")
      |> mes("Aren't you leaving?")
      |> close()
    else
      {ctx, _} =
        ctx
        |> mes("[Mirhen]")
        |> mes("Huh? What's this name")
        |> mes("tag? Zabaroo? Wait a sec...")
        |> mes("You're definitely not him!")
        |> next()
        |> select(["I'm here on his behalf."])

      ctx
      |> mes("[Mirhen]")
      |> mes("Ah, I get it. Zabaroo's")
      |> mes("back has really been")
      |> mes("bothering him lately.")
      |> mes("Okay, we can bend the")
      |> mes("rules a bit in this situation.")
      |> next()
      |> mes("[Mirhen]")
      |> mes("Bring those rocks over")
      |> mes("to Bahed over there.")
      |> mes("He'll take care of them.")
      |> set_char_var(:veins_stone, 6)
      |> close()
    end
  end
end
