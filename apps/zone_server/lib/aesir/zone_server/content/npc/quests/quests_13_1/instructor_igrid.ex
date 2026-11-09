defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.InstructorIgrid do
  @moduledoc """
  Instructor Igrid of the Midgard Expedition, who judges recruits by their progress in the
  Ash-Vacuum quest.

  ## Behavior

  - Congratulates a player who finished the mission (steps 13 and 14).
  - At step 0, and while a recruit is still on steps 1 to 3, refuses to train them; the lines
    get harsher on steps 4 and 5 and on any step above 5.
  - Falls back to her introduction for a negative step.

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
        map: "mid_campin",
        x: 85,
        y: 118,
        dir: 7,
        sprite: 751,
        name: "Instructor Igrid",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_1_edq, 0) do
      step when step in [13, 14] -> mission_done(ctx)
      0 -> too_weak(ctx)
      step when step > 0 and step < 4 -> distrusted(ctx)
      step when step in [4, 5] -> gave_up(ctx)
      step when step > 5 -> idle_soldiers(ctx)
      _step -> introduction(ctx)
    end
  end

  defp mission_done(ctx) do
    ctx
    |> mes("[Instructor Igrid]")
    |> mes("Hey, rookies. I guess you were lucky enough to complete the mission.")
    |> next()
    |> mes("[Instructor Igrid]")
    |> mes("This is not the end. Keep yourself in one piece until we need your services again.")
    |> close()
  end

  defp too_weak(ctx) do
    ctx
    |> mes("[Instructor Igrid]")
    |> mes(
      "I'm Instructor Igrid of the Midgard Expedition. I'm in charge of training and commanding soldiers."
    )
    |> next()
    |> mes("[Instructor Igrid]")
    |> mes("You must want to become an official member of our expedition.")
    |> mes("I'm sorry, but you're too weak to endure my intensive training.")
    |> mes("Give up before you get hurt.")
    |> next()
    |> mes("[Instructor Igrid]")
    |> mes(
      "If you have too much time on your hands, look around. There's plenty of chores available for so-called adventurers's like you."
    )
    |> mes("If you do your best to do them, I might accept you as a trainee on this expedition.")
    |> close()
  end

  defp distrusted(ctx) do
    ctx
    |> mes("[Instructor Igrid]")
    |> mes(
      "I don't trust you. Hm. Sorry. I don't really have the right to say that if the commander has assigned you to the mission."
    )
    |> next()
    |> mes("[Instructor Igrid]")
    |> mes("If you're going to give up, give up now. That'll be better for both of us.")
    |> close()
  end

  defp gave_up(ctx) do
    ctx
    |> mes("[Instructor Igrid]")
    |> mes("I knew you couldn't do it. Didn't I tell you to give up when you had the chance?!")
    |> close()
  end

  defp idle_soldiers(ctx) do
    ctx
    |> mes("[Instructor Igrid]")
    |> mes(
      "Do you think I'm doing this for you? No, I'm just using this chance to discipline idle soldiers."
    )
    |> next()
    |> mes("[Instructor Igrid]")
    |> mes("What are you looking at? Go mind your own business!")
    |> close()
  end

  defp introduction(ctx) do
    ctx
    |> mes("[Instructor Igrid]")
    |> mes(
      "I am Expedition Training Instructor Igrid, and the commander responsible for training soldiers. "
    )
    |> close()
  end
end
