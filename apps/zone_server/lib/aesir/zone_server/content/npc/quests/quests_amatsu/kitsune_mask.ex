defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.KitsuneMask do
  @moduledoc """
  Teaches travelers how to confront the fox possessing Ishida Saoko.

  ## Behavior

  - Advances the exorcism quest and provides advice.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_in01",
        x: 180,
        y: 173,
        dir: 3,
        sprite: 762,
        name: "Kitsune Mask",
        scope: :shared,
        unique_name: "Kitsune Mask#ama"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :event_amatsu, 0) do
      3 ->
        {ctx, _} =
          ctx
          |> mes("[Takehue]")
          |> mes("Eh, you are a foreigner.")
          |> mes("I'm sure you visited me because")
          |> mes("you are having fox troubles.")
          |> mes("I can see that in your face.")
          |> next()
          |> mes("[Takehue]")
          |> mes("Originally, the head priest should")
          |> mes("help you, but this shrine has been")
          |> mes("abandoned long ago.")
          |> next()
          |> mes("[Takehue]")
          |> mes("It is hard to expel a fox from")
          |> mes("a human body. If you have liquor")
          |> mes("and noodles with fried bean curd,")
          |> mes("it would be easy, but they are hard to find.")
          |> next()
          |> mes("[Takehue]")
          |> mes("I know a little about foxes, so let me tell you something...")
          |> mes("Foxes like to tease people but")
          |> mes("it is rare for them to crave")
          |> mes("vengeance.")
          |> mes(" ")
          |> next()
          |> mes("[Takehue]")
          |> mes("If a fox is vengeful, it means that a human caused it harm.")
          |> mes("The fox will take its revenge")
          |> mes("against, you, your family,")
          |> mes("even your close friends!")
          |> next()
          |> mes("[Takehue]")
          |> mes("Anyway, a stronger spirit")
          |> mes("will expel the fox from a human.")
          |> mes("Come on, yell out and show me your spirit!")
          |> mes(" ")
          |> next()
          |> select(["Taaaaah!!"])

        ctx =
          ctx
          |> set_char_var(:event_amatsu, 4)
          |> mes("[Takehue]")
          |> mes("Good. Show that spiritual")
          |> mes("energy to the fox several times.")
          |> mes("Sooner or later, you'll be successful.")

        ctx =
          cond do
            isbegin_quest(ctx, 8132) == 1 -> changequest(ctx, 8132, 8134)
            isbegin_quest(ctx, 8133) == 1 -> changequest(ctx, 8133, 8134)
            true -> ctx
          end

        close(ctx)

      4 ->
        ctx
        |> mes("[Takehue]")
        |> mes("Don't forget. You also need the")
        |> mes("the embodiment of animals stronger")
        |> mes("than the fox. Without these, your")
        |> mes("concentration will be of no use.")
        |> close()

      _ ->
        ctx
        |> mes("[Takehue]")
        |> mes("Eh? A foreigner. This shrine")
        |> mes("has been without priests for a")
        |> mes("long time. My friend, Tokako and I come here to play around.")
        |> next()
        |> mes("[Takehue]")
        |> mes("If you have been chased by")
        |> mes("monsters, please relax.")
        |> mes("Monsters cannot come here, so")
        |> mes("take a rest in here.")
        |> close()
    end
  end
end
