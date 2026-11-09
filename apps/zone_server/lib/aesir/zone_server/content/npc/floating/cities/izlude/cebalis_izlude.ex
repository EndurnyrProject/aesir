defmodule Aesir.ZoneServer.Content.Npc.Floating.Cities.Izlude.CebalisIzlude do
  @moduledoc """
  Cebalis, who argues with Red about Bash versus Magnum Break.

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
        x: 55,
        y: 159,
        dir: 2,
        sprite: 98,
        name: "Cebalis",
        scope: :renewal,
        unique_name: "Cebalis#izlude"
      },
      %{
        map: "izlude_a",
        x: 55,
        y: 159,
        dir: 2,
        sprite: 98,
        name: "Cebalis",
        scope: :renewal,
        unique_name: "Cebalis#izlude_a"
      },
      %{
        map: "izlude_b",
        x: 55,
        y: 159,
        dir: 2,
        sprite: 98,
        name: "Cebalis",
        scope: :renewal,
        unique_name: "Cebalis#izlude_b"
      },
      %{
        map: "izlude_c",
        x: 55,
        y: 159,
        dir: 2,
        sprite: 98,
        name: "Cebalis",
        scope: :renewal,
        unique_name: "Cebalis#izlude_c"
      },
      %{
        map: "izlude_d",
        x: 55,
        y: 159,
        dir: 2,
        sprite: 98,
        name: "Cebalis",
        scope: :renewal,
        unique_name: "Cebalis#izlude_d"
      },
      %{
        map: "izlude",
        x: 58,
        y: 126,
        dir: 2,
        sprite: 98,
        name: "Cebalis",
        scope: :pre_renewal,
        unique_name: "Cebalis#izlude"
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
      "The only skill that's needed for a Swordman is ^FF2400Bash^000000! Bash, Bash and ONLY ^FF2400Bash^000000! No need to waste time and effort on smaller skills~~ Everything else is for cowards and wusses!"
    )
    |> next()
    |> mes("[Cebalis]")
    |> mes(
      "What are you talking about!? The ideal Swordman resolutely stands alone, surrounded by countless foes, smashing them all with one awesome attack..."
    )
    |> next()
    |> mes("[Cebalis]")
    |> mes("^EE0000MAGNUM BREAK!^000000")
    |> mes("That's right, Magnum Break")
    |> mes("is the perfect")
    |> mes("Swordman skill.")
    |> next()
    |> mes("[Cebalis]")
    |> mes("Well...")
    |> mes(
      "Sometimes the explosion accidentally hits some monsters that are just wandering around."
    )
    |> next()
    |> mes("[Cebalis]")
    |> mes(
      "Then they all end up coming after you, but that's a risk a true Swordman should be willing to take."
    )
    |> next()
    |> mes("[Red]")
    |> mes(
      "That's exactly why you're dumb, you idiot! And what was that about the 'ideal Swordman?' You remember the last time you used Magnum Break?!"
    )
    |> next()
    |> mes("[Red]")
    |> mes(
      "You had to run away from all those Porings hit by that stupid skill! You weakling! All those Porings that you hit tried to kill you! "
    )
    |> next()
    |> mes("[Cebalis]")
    |> mes(
      "Oh shut up. And those were Poporings. As I recall, you were running away too, apparently too busy to use your precious Bash."
    )
    |> next()
    |> mes("[Cebalis]")
    |> mes(
      "In any case, Magnum Break is THE skill for a Swordman~!! Something simplistic like Bash is just one of those little steps towards Magnum Break."
    )
    |> next()
    |> mes("[Red]")
    |> mes("Oh man~")
    |> mes("Hey, I know you")
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
        "Hahahaha!!! I knew you'd see things my way!! You ARE a great guy!! Without a doubt, only ^FF2400Bash^000000 suits a Swordman. Please tell that to FUNBOY over here!! Hahaha."
      )
      |> next()
      |> mes("[Red]")
      |> mes(
        "Hmm, let me give you a bit of advice. After you achieve level 5 Bash, the amount of SP consumed by the skill increases greatly, so watch out for your SP."
      )
      |> close()
    else
      ctx
      |> mes("[Red]")
      |> mes("Hahahaha!!")
      |> mes(
        "See!? Someone who pursues a different job agrees with me~! You really are a great guy! Hahaha!!"
      )
      |> next()
      |> mes("[Red]")
      |> mes(
        "Without a doubt, only ^FF2400Bash^000000 suits a Swordman. Please tell that to this MORON over here!! Hahaha~"
      )
      |> close()
    end
  end

  defp magnum_break_supporter(ctx) do
    if base_class(ctx) == :swordman do
      ctx
      |> mes("[Cebalis]")
      |> mes(
        " Alright!! ^EE0000Magnum Break^000000 is the BEST!! Now you're talking~!! You know your stuff, kid. HaHaHa~!"
      )
      |> next()
      |> mes("[Cebalis]")
      |> mes(
        "You wanna know some useful information? Okay, okay lemme tell ya! The explosion from 'Magnum Break' has the Fire Property."
      )
      |> next()
      |> mes("[Cebalis]")
      |> mes(
        "So it won't be very effective against Water property monsters, but this is THE skill to use against Undead and Earth property monsters.!"
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
        "I'm right, aren't I?! ^EE0000Magnum Break^000000 is THE BEST!!! You know what you're talking about, eh? I don't know why this LARDFACE is sooooo stubborn."
      )
      |> close()
    end
  end
end
