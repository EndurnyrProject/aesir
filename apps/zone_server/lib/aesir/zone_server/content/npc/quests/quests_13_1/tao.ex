defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Tao do
  @moduledoc """
  Tao, the cat doorkeeper of the Morocc hideout who guards Rin's room and Marjana's.

  ## Behavior

  - Assassins are greeted with a menu: with `prt_curse` 24 they can ask for Marjana, otherwise
    Tao hints at Rin once `mao_morocc2` is past step 4, or only scolds the visitor.
  - Everyone else gets a three-option menu: calling Tao a kid reveals that Master and Marjana
    are in the left room, mocking their post gets the visitor thrown out, and asking about the
    meowing gets the Big Ribbon story before the same dismissal.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_job01",
        x: 49,
        y: 49,
        dir: 5,
        sprite: 877,
        name: "Tao",
        scope: :shared,
        unique_name: "Tao#dan_09"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Tao]")

    if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:assassin) do
      assassin_visitor(ctx)
    else
      stranger_menu(ctx)
    end
  end

  defp assassin_visitor(ctx) do
    ctx = ctx |> mes("Welcome, meow.") |> mes("Say, how's it like outside? Meow?") |> next()

    cond do
      get_char_var(ctx, :prt_curse, 0) == 24 -> marjana_menu(ctx)
      get_char_var(ctx, :mao_morocc2, 0) > 4 -> rin_hint(ctx)
      true -> not_a_guest(ctx)
    end
  end

  defp marjana_menu(ctx) do
    {ctx, choice} = select(ctx, ["Is Marjana in?", "I'm here to see you, Tao."])

    case choice do
      1 -> marjana_hint(ctx)
      2 -> no_playing(ctx)
      _cancelled -> ctx
    end
  end

  defp marjana_hint(ctx) do
    ctx
    |> mes("[Tao]")
    |> mes("She's in the room on your left, meow~")
    |> mes("But then, how d'you know she's here, meow?")
    |> close()
  end

  defp no_playing(ctx) do
    ctx
    |> mes("[Tao]")
    |> mes("This is no place for playing, meow..")
    |> mes("... Hey, it's awkward you looking at me like that, meow..")
    |> close()
  end

  defp rin_hint(ctx) do
    ctx
    |> mes("[Tao]")
    |> mes(
      "Tao knows what you're thinking, meow~ You're here to see big sister Rin, am I right, meow? "
    )
    |> mes("Hehe, where is she, I wonder, meow~")
    |> close()
  end

  defp not_a_guest(ctx) do
    ctx
    |> mes("[Tao]")
    |> mes("If you don't have any reason to be here, you should leave, meow!")
    |> mes("Not everyone can enter this place, meow.")
    |> mes("Somehow you're here, but you can't go in the room.")
    |> next()
    |> mes("[Tao]")
    |> mes("No, wait... I think you may be able to go in... I don't know, meow!")
    |> mes("Tao is tired of being a door keeper, meow! Meow!")
    |> close()
  end

  defp stranger_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Why are you here, meow?")
      |> next()
      |> select([
        "Hey kid, are you alone?",
        "What are you, meow?!",
        "Why do you keep meowing?!"
      ])

    case choice do
      1 -> called_a_kid(ctx)
      2 -> mocked(ctx)
      3 -> meowing_story(ctx)
      _cancelled -> ctx
    end
  end

  defp called_a_kid(ctx) do
    ctx
    |> mes("[Tao]")
    |> mes("Who are you calling a kid?")
    |> mes("Tao is a good door keeper!")
    |> mes("Don't call me a kid!")
    |> next()
    |> mes("[Tao]")
    |> mes(
      "I can tell you've got some reason for being here, but you've put yourself in trouble!"
    )
    |> mes("You're mistaken if you thought I would tell you")
    |> mes("Master and Marjana are in the left room. Grrr.. Meow!")
    |> close()
  end

  defp mocked(ctx) do
    ctx
    |> mes("[Tao]")
    |> mes("Are you making fun of me being a door keeper, meow?!")
    |> mes("Grrr...")
    |> next()
    |> mes("[Tao]")
    |> mes("You make me mad, meow. Get lost!!")
    |> close()
  end

  defp meowing_story(ctx) do
    ctx
    |> mes("[Tao]")
    |> mes("It's a long story, meow.")
    |> mes("It's been a long time since I started meowing one day..")
    |> mes("That day, Tao wanted to have a Big Ribbon so badly.")
    |> next()
    |> mes("[Tao]")
    |> mes("So Tao went to find Wild Roses.")
    |> mes("Meow?! Why am I telling you this, meow?!")
    |> next()
    |> mes("[Tao]")
    |> mes("Grrr!")
    |> mes("What are you, meow?!")
    |> next()
    |> mes("[Tao]")
    |> mes("Get out!")
    |> close()
  end
end
