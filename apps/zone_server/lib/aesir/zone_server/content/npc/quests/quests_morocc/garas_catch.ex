defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.GarasCatch do
  @moduledoc """
  A crow encounter outside the library advances the Crow of the Fate quest.

  ## Behavior

  - At the appropriate quest stage, the player witnesses the crow and picks up a feather.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "yuno",
        x: 336,
        y: 203,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#garas_catch",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :barmunt_crow, 0) == 2 do
      ctx
      |> mes("[Dog]")
      |> mes("Bowwow!")
      |> mes("Grrr... Bowwow!")
      |> next()
      |> mes("^660000A dog is barking loudly at the front of the library.^000000")
      |> next()
      |> mes("[Library Master]")
      |> mes("You damn bird! Fly away, leave!")
      |> next()
      |> mes("^660000A man is also yelling at the front of the library.^000000")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("What's happening here?")
      |> next()
      |> mes("[Library Master]")
      |> mes(
        "It's nothing, but there's a gigantic crow sitting on the roof of this library, crowing for at least a few hours now."
      )
      |> mes("I was trying to drive it away because... It feels ominous somehow.")
      |> next()
      |> mes("[Library Master]")
      |> mes("Go! Fly away, you damn bird! Leave!!")
      |> next()
      |> mes(
        "^660000You looked up, and found a huge crow sitting on the roof of the library as if it owned the place.^000000"
      )
      |> next()
      |> mes("[Library Master]")
      |> mes("Leave! Gosh, it won't go away!")
      |> mes("I'm afraid that creepy bird will scare away my patrons!")
      |> next()
      |> mes("[Library Master]")
      |> mes("Umm... Oh, well.")
      |> mes("(Grabbing a pebble)")
      |> mes("I said go away, you stupid bird!")
      |> next()
      |> mes("(WHIZZ-)")
      |> next()
      |> mes("(THUD!)")
      |> specialeffect(:pierce)
      |> next()
      |> mes("(Gush)")
      |> next()
      |> mes(
        "^660000Hit by the pebble which the man threw, the crow quickly flew up into the air.^000000"
      )
      |> mes(
        "^660000But then it started flying above the roof in a circle, and looked even spookier.^000000"
      )
      |> specialeffect(:bat)
      |> next()
      |> mes("[Library Master]")
      |> mes("Grrr... Can't you just go away?!")
      |> next()
      |> mes(
        "^660000He started yelling at the crow, but it didn't seem to care. Instead, it flew up a little higher."
      )
      |> mes(
        "Eventually he turned his head away from the crow, and gave up on driving it away. Then the dog stopped barking as well.^000000"
      )
      |> next()
      |> mes(
        "^660000You looked down on the ground, and then found a couple of feathers dropped from the crow when it was hit by the pebble.^000000"
      )
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "Wow, look at the size of these feathers. I guess such a huge crow needs big feathers to fly."
      )
      |> next()
      |> mes("[Library Master]")
      |> mes(
        "When I was young, I heard that bird feathers bring Odin's servants to bless their owner, and so many poets used them as bookmarks."
      )
      |> next()
      |> mes("[Library Master]")
      |> mes(
        "I used to have a small feather. I guess it's only natural that I've become a library master. Hahaha!"
      )
      |> next()
      |> mes("[Library Master]")
      |> mes(
        "You know the old saying, 'you can memorize Edda after 3 years of working at a library.'"
      )
      |> mes("Why don't you keep one of the feathers? Who knows? It may bring you good luck.")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I guess so.")
      |> next()
      |> mes("^660000You picked up one of the big dark feathers from the ground.")
      |> mes(
        "Looking at the lustrous feather somehow made you feel so happy, as if you had obtained treasure.^000000"
      )
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...Ahchoo!")
      |> specialeffect2(:venomdust)
      |> next()
      |> mes("[Library Master]")
      |> mes("God bless you. Oh, did you catch cold?")
      |> mes("You should take good care of yourself, especially if you're an adventurer.")
      |> next()
      |> mes("^660000You started feeling cold and began to shiver.^000000")
      |> next()
      |> mes("[Library Master]")
      |> mes(
        "Try to drink hot Jellopy broth mixed with honey. My mother used to make that for me whenever I caught cold."
      )
      |> mes("I gurantee you that you'll get better quickly.")
      |> next()
      |> mes(
        "^660000He sounded sincere, but it doesn't sound like that kind of broth would even be effective...^000000"
      )
      |> emotion(:think, playerattached(ctx))
      |> set_char_var(:barmunt_crow, 3)
      |> close()
    else
      ctx
    end
  end
end
