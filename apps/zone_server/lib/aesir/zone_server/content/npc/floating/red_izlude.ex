defmodule Aesir.ZoneServer.Content.Npc.Floating.RedIzlude do
  @moduledoc """
  Red, who argues with Cebalis about Bash versus Magnum Break.

  ## Behavior

  - Plays out the two Swordmen's argument about the only skill a Swordman
    needs, then asks the player to pick a side.
  - Picking Bash gets a Swordman a tip about Bash's rising SP cost at level 5;
    any other job gets a shorter cheer.
  - Picking Magnum Break gets a Swordman the Fire property tip and a warning to
    check the surroundings first.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Nexon
    - Silentdragon
    - MasterOfMuppets
    - Silent
    - Evera
    - CAHTEXHuK
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script cities/izlude.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "izlude",
        x: 57,
        y: 159,
        dir: 2,
        sprite: 85,
        name: "Red",
        scope: :renewal,
        unique_name: "Red#izlude"
      },
      %{
        map: "izlude_a",
        x: 57,
        y: 159,
        dir: 2,
        sprite: 85,
        name: "Red",
        scope: :renewal,
        unique_name: "Red#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 57,
        y: 159,
        dir: 2,
        sprite: 85,
        name: "Red",
        scope: :renewal,
        unique_name: "Red#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 57,
        y: 159,
        dir: 2,
        sprite: 85,
        name: "Red",
        scope: :renewal,
        unique_name: "Red#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 57,
        y: 159,
        dir: 2,
        sprite: 85,
        name: "Red",
        scope: :renewal,
        unique_name: "Red#izlude_d"
      },
      %{
        map: "izlude",
        x: 56,
        y: 126,
        dir: 2,
        sprite: 85,
        name: "Red",
        scope: :pre_renewal,
        unique_name: "Red#izlude"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, favourite} =
      ctx
      |> argument()
      |> select(["Bash", "Magnum Break"])

    if favourite == 1 do
      bash_supporter(ctx)
    else
      magnum_break_supporter(ctx)
    end
  end

  defp argument(ctx) do
    ctx
    |> mes("[Red]")
    |> mes(
      "The only skill that's needed for a Swordman is ^FF2400Bash^000000! Bash, Bash and ONLY ^FF2400Bash^000000! No need to waste time and effort for smaller skills! Everything else is for cowards and wusses!"
    )
    |> next()
    |> mes("[Cebalis]")
    |> mes(
      "What are you talking about!? The ideal Swordman resolutely stands alone, surrounded by countless enemies and smashing them all with one awesome attack."
    )
    |> next()
    |> mes("[Cebalis]")
    |> mes("^EE0000MAGNUM BREAK!^000000")
    |> mes("That's right, Magnum Break")
    |> mes("is the skill that does")
    |> mes("the job right~!!")
    |> next()
    |> mes("[Cebalis]")
    |> mes(
      "Well... Sometimes the explosive damage might accidentally hit some wandering monsters, and those guys end up coming after you, but that's a risk a Swordman should be willing to take!!"
    )
    |> next()
    |> mes("[Red]")
    |> mes(
      "That's exactly why you're dumb, you idiot! And what's this about the 'the ideal Swordman?' I still remember the last time you used Magnum Break..."
    )
    |> next()
    |> mes("[Red]")
    |> mes(
      "You ended up running away from all those monsters you hit with that stupid skill! Weakling! All those Porings around you got hit and they all tried to kill you. "
    )
    |> next()
    |> mes("[Cebalis]")
    |> mes(
      "Hmpf. As I recall, you were running away too, apparently too busy to use your precious Bash. In any case, Magnum Break is THE skill for a Swordman~!!"
    )
    |> next()
    |> mes("[Cebalis]")
    |> mes("Something simplistic like Bash")
    |> mes("is just one of the little steps towards Magnum Break.")
    |> next()
    |> mes("[Red]")
    |> mes("Oh man~")
    |> mes("Hey, I know you just")
    |> mes("heard everything.")
    |> mes("So what do you think?")
    |> next()
    |> mes("[Red]")
    |> mes(
      "Which one do you think is better? The critical damage skill, ^FF2400Bash^000000, or the Splash damage skill, ^EE0000Magnum Break^000000?"
    )
    |> next()
  end

  defp bash_supporter(ctx) do
    if base_class(ctx) == :swordman do
      ctx
      |> mes("[Red]")
      |> mes(
        "Hahahaha!!! I knew you'd see things my way!! You ARE a great guy!! Undoubtedly, only ^FF2400Bash^000000 suits a Swordman. Please tell that to this BONEHEAD over here~ Hahaha!"
      )
      |> next()
      |> mes("[Red]")
      |> mes(
        "Hmm, let me give you a bit of advice. After you achieve level 5 'Bash', the amount of SP consumed by the skill increases greatly, so watch out for your SP."
      )
      |> close()
    else
      ctx
      |> mes("[Red]")
      |> mes(
        "Hahahaha!! See!? Someone who pursues a different job agrees with me~! You really are a great guy! Hahaha!! Undoubtedly, only ^FF2400Bash^000000 suits a Swordman. Please tell that to this NIMROD over here~ Hahaha!"
      )
      |> close()
    end
  end

  defp magnum_break_supporter(ctx) do
    if base_class(ctx) == :swordman do
      ctx
      |> mes("[Cebalis]")
      |> mes(
        "Alright!! ^EE0000Magnum Break^000000 is the BEST!! Now you're talking~!! You know the stuff~ HaHaHa!"
      )
      |> next()
      |> mes("[Cebalis]")
      |> mes(
        "You wanna know some useful information? Okay, okay lemme tell ya! Magnum Break has Fire Property."
      )
      |> next()
      |> mes("[Cebalis]")
      |> mes(
        "So it won't be too effective against monsters with the Water property, but this is THE skill to use against Undead and Earth property monsters!"
      )
      |> next()
      |> mes("[Cebalis]")
      |> mes(
        "And most importantly, look around before you use it. Otherwise you'll be in BIG trouble~ "
      )
      |> close()
    else
      ctx
      |> mes("[Cebalis]")
      |> mes(
        "Right?! ^EE0000Magnum Break^000000 is THE BEST!!! You know what you're talking about, eh? I don't know why this jerkface is being sooooo stubborn."
      )
      |> close()
    end
  end
end
