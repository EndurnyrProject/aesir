defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.WizardSkills.SimonMayace do
  @moduledoc """
  Simon teaches push-back technique for the Wizard Sight Blaster skill quest.

  ## Behavior

  - Explains push-back technique once Meow has sent the player to him.
  - Advances the quest so Meow can teach Sight Blaster.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - L0ne_W0lf
    - DracoRPG
    - Toms

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/wizard_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 82,
        y: 98,
        dir: 3,
        sprite: 46,
        name: "Simon Mayace",
        scope: :shared,
        unique_name: "Simon Mayace#q_wiz"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :WIZ_SK, 0) == 1 do
      offer_lesson(ctx)
    else
      ctx
      |> mes("[Simon]")
      |> mes("Make no mistake:")
      |> mes("swordplay is an art.")
      |> mes("The techniques may seem")
      |> mes("brutish at first glance, but")
      |> mes("there's a keen strategy that")
      |> mes("Knights innately understand.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp offer_lesson(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Simon]")
      |> mes("Ah, you must be a skilled")
      |> mes("practitioner of magic. Mmm,")
      |> mes("you must one of those Wizards.")
      |> mes("High Wizards? I can't really")
      |> mes("tell the difference. Ah, may")
      |> mes("I be of service to you?")
      |> next()
      |> select(["I'm fine, thank you.", "I want to learn about push backs."])

    if choice == 1 do
      ctx
      |> mes("[Simon]")
      |> mes("I'm surprised that you chose")
      |> mes("to practice magic: judging")
      |> mes("from your build, I'd say that")
      |> mes("you'd be well suited to wielding a sword. Haha, but that's just")
      |> mes("a humble Knight's opinion.")
      |> close()
    else
      teach_push_back(ctx)
    end
  end

  defp teach_push_back(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Simon]")
      |> mes("Wait, are you asking me")
      |> mes("to teach you a Push-Back")
      |> mes("attack technique? You can")
      |> mes("defend yourself using spells")
      |> mes("like Fire Wall or Fire Bolt")
      |> mes("much more effectively, right?")
      |> next()
      |> select(["But at close range..."])

    ctx
    |> mes("[Simon]")
    |> mes("Oh, I see. Yeah, Wizards")
    |> mes("aren't very effective in close")
    |> mes("range battles. Okay, I can see")
    |> mes("why you'd want to learn some")
    |> mes("Push-Back technique. Alright,")
    |> mes("I can teach you a few basics.")
    |> next()
    |> mes("[Simon]")
    |> mes("Now, every adventurer knows")
    |> mes("the fundamentals of attacking.")
    |> mes("You strike, and then ready your")
    |> mes("next action, which is either")
    |> mes("another strike, a dodge or a")
    |> mes("guard. Simple stuff, right?")
    |> next()
    |> mes("[Simon]")
    |> mes("To push an enemy back, you've")
    |> mes("got to attack using a strike")
    |> mes("with continuous force. It's all")
    |> mes("in the follow through. Now, if")
    |> mes("you strike the head, the push")
    |> mes("distance will be too short.")
    |> next()
    |> mes("[Simon]")
    |> mes("If you deliver a pushing")
    |> mes("strike to the legs, your")
    |> mes("enemy will fall towards you.")
    |> mes("The best target for pushing")
    |> mes("attacks is the torso since it")
    |> mes("allows more control of the push.")
    |> next()
    |> mes("[Simon]")
    |> mes("Well, I've explained")
    |> mes("pushing as best as I can.")
    |> mes("Concentrate and practice the")
    |> mes("theory on your own, and you")
    |> mes("should be able to do it. Good luck on your travels, adventurer~")
    |> set_char_var(:WIZ_SK, 2)
    |> close()
  end
end
