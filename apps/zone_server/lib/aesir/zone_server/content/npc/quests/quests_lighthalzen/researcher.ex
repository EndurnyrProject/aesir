defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Researcher do
  @moduledoc """
  Lestin is a researcher and Secret Wing contact.

  ## Behavior

  - Offers a wire-cutting question and recognizes the player’s card.
  - Transfers identified agents to a private room.

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
        map: "lhz_in01",
        x: 93,
        y: 45,
        dir: 4,
        sprite: 865,
        name: "Researcher",
        scope: :shared,
        unique_name: "Researcher#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :lhz_boss, 0) < 28 do
      ctx =
        ctx
        |> mes("[Researcher]")
        |> mes("You know what's weird?")
        |> mes("Why do they use blue and")
        |> mes("red wires when they make")
        |> mes("bombs? There's so many")
        |> mes("others you could use, like")
        |> mes("pink or yellow or or green...")

      if get_char_var(ctx, :lhz_boss, 0) == 27, do: ask_wire(ctx), else: close(ctx)
    else
      ctx
      |> mes("[Lestin]")
      |> mes("Geez, I've been so")
      |> mes("tired lately. Work?")
      |> mes("Forget it, I'm gonna")
      |> mes("just kick back today~")
      |> close()
    end
  end

  defp ask_wire(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Researcher]")
      |> mes("Hey, here's a completely")
      |> mes("hypothetical question. Let's")
      |> mes("say you find a bomb and it's")
      |> mes("about to go off. You better")
      |> mes("cut a wire! So which one are")
      |> mes("you gonna cut? Red or blue?")
      |> next()
      |> select(["Red", "Blue"])

    case choice do
      1 ->
        choose_red(ctx)

      2 ->
        ctx
        |> mes("[Researcher]")
        |> mes("Blue, huh? Yeah,")
        |> mes("that's what everyone")
        |> mes("else here picks. Now")
        |> mes("what color would I pick?")
        |> mes("Well, that's a secret~")
        |> close()

      _ ->
        ctx
    end
  end

  defp choose_red(ctx) do
    ctx =
      ctx
      |> mes("[Researcher]")
      |> mes("Red, eh...?")
      |> mes("...................")
      |> mes("Heh, yeah, just like")
      |> mes("in the movies. I like")
      |> mes("the way you think~")

    if Rathena.truthy?(count_item(ctx, 7348)), do: identify_lestin(ctx), else: close(ctx)
  end

  defp identify_lestin(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> mes("^3355FFYou surrepticiously")
      |> mes("check the researcher's")
      |> mes("ID badge and see that the name ''Lestin'' is written on it.^000000")
      |> next()
      |> mes("[Lestin]")
      |> mes("So...")
      |> mes("Is there anything")
      |> mes("I can help you with?")
      |> next()
      |> select(["No", "Yes"])

    case choice do
      1 ->
        ctx
        |> mes("[Lestin]")
        |> mes("Alright then.")
        |> mes("Just be quiet when")
        |> mes("you're in the Laboratory.")
        |> mes("The people here work")
        |> mes("pretty feverishly and get")
        |> mes("irritated pretty easily, okay?")
        |> close()

      2 ->
        show_card(ctx)

      _ ->
        ctx
    end
  end

  defp show_card(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lestin]")
      |> mes("So what exactly did")
      |> mes("you need? I'm just an")
      |> mes("ordinary researcher,")
      |> mes("so I don't know how")
      |> mes("much help I could be...")
      |> next()
      |> select(["Show Secret Wing Card."])

    case choice do
      1 ->
        ctx
        |> mes("[Lestin]")
        |> mes("Whoa, whoa~!")
        |> mes("Careful where you")
        |> mes("flash that! Okay, I know")
        |> mes("who you are. But we better")
        |> mes("continue this someplace")
        |> mes("a bit more private...")
        |> close2()
        |> warp("lhz_in01", 283, 166)

      _ ->
        ctx
    end
  end
end
