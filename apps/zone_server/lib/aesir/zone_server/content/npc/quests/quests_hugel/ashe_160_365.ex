defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Ashe160365 do
  @moduledoc """
  Ashe’s contact receives the file and explains the excavation.

  ## Behavior

  - Answers the player’s question and rewards completion of the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild12",
        x: 160,
        y: 365,
        dir: 0,
        sprite: 139,
        name: "Ashe",
        scope: :shared,
        unique_name: "Ashe#4",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_odin, 0) == 59 do
      receive_file(ctx)
    else
      ctx
    end
  end

  defp receive_file(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[???]")
      |> mes("...Silence.")
      |> next()
      |> mes("[???]")
      |> mes("Don't turn, don't")
      |> mes("flinch, don't even")
      |> mes("breathe. You're being")
      |> mes("followed. Hold on a sec")
      |> mes("while I take care of him.")
      |> next()
      |> specialeffect(:sonicblowhit, :area, "Hit")
      |> mes("[???]")
      |> mes("Ha!")
      |> next()
      |> mes("[???]")
      |> mes("...............................")
      |> mes("Good. You've done some")
      |> mes("good work. Just drop the file")
      |> mes("to the ground. And for your")
      |> mes("own good, don't turn around.")
      |> next()
      |> mes("^3355FFYou drop the file")
      |> mes("to the ground, and it")
      |> mes("immediately vanishes in")
      |> mes("a small whirlwind of sand.^000000")
      |> next()
      |> mes("[???]")
      |> mes("I know that you've")
      |> mes("gotten involved in all")
      |> mes("this unexpectedly. Before")
      |> mes("I leave, have you got any")
      |> mes("questions? Otherwise, I'll go.")
      |> next()
      |> select(["Who's Ashe?", "What happened to Laura?"])

    case choice do
      1 ->
        ctx
        |> mes("[???]")
        |> mes("You'll never see her")
        |> mes("again. She's already")
        |> mes("been assigned to a new")
        |> mes("mission. If it makes you")
        |> mes("feel better, she's one of the")
        |> mes("members of ''Secret Wing.''")
        |> next()
        |> explain_and_reward()

      2 ->
        ctx
        |> mes("[???]")
        |> mes("She'll be fine. If you're that")
        |> mes("interested in archaeology,")
        |> mes("you'll be happy to know that")
        |> mes("she'll run the excavation the")
        |> mes("way she wants to. Rekenber and Arunafeltz should leave her alone.")
        |> next()
        |> mes("[???]")
        |> mes("You're probably curious")
        |> mes("about Ashe, and perhaps")
        |> mes("myself as well. Now, have you")
        |> mes("ever heard of ''Secret Wing?''")
        |> next()
        |> explain_and_reward()

      _ ->
        ctx
    end
  end

  defp explain_and_reward(ctx) do
    ctx
    |> mes("[???]")
    |> mes("Secret Wing is a secret")
    |> mes("organization that's scattered")
    |> mes("now, but some of the members")
    |> mes("are still active. Just consider us enemies of Rekenber Corporation")
    |> mes("in the Schwarzwald Republic.")
    |> next()
    |> mes("[???]")
    |> mes("Everything you saw and")
    |> mes("heard is all true. The ghost")
    |> mes("of Giantes still remains within")
    |> mes("the Odin Shrine. Rekenber wants")
    |> mes("it for their ends, as well as")
    |> mes("Arunafeltz. It's complicated...")
    |> next()
    |> mes("[???]")
    |> mes("The people of Rune-Midgarts")
    |> mes("and Schwarzwald Republic still")
    |> mes("don't know what's going on.")
    |> mes("A lot of people are just being")
    |> mes("used... Like that one lady,")
    |> mes("that archaeologist, Laura.")
    |> next()
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 100_000, else: 700_000), 0)
    |> set_char_var(:hg_odin, 60)
    |> completequest(11008)
    |> mes("[???]")
    |> mes("...Thanks for")
    |> mes("the file. Take care.")
    |> mes("Always watch your back.")
    |> close()
  end
end
