defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Julian do
  @moduledoc """
  Julian comments on the Odin Shrine excavation.

  ## Behavior

  - His dialogue changes with the player’s progress.

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
    spawn: [%{map: "hu_in01", x: 18, y: 167, dir: 4, sprite: 86, name: "Julian", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :hg_odin, 0)

    cond do
      not Rathena.truthy?(progress) ->
        ctx |> mes("[Julian]") |> mes("^333333*Sigh...*^000000") |> close()

      progress == 1 ->
        ctx
        |> mes("[Julian]")
        |> mes("Say, are you here")
        |> mes("for a job? We're looking")
        |> mes("for someone that's passionate")
        |> mes("about ancient history. If you")
        |> mes("want to make money, then this")
        |> mes("this the wrong place for you~")
        |> next()
        |> mes("[Julian]")
        |> mes("This is supposed to be")
        |> mes("a collaborative excavation,")
        |> mes("but the team leaders are too")
        |> mes("stubborn and refuse to make")
        |> mes("any compromises. It's been")
        |> mes("incredibly frustrating...")
        |> next()
        |> mes("[Julian]")
        |> mes("Basically, each of our teams")
        |> mes("is conducting its own research")
        |> mes("for now. Now, we need your help")
        |> mes("to find any relics from the Odin Shrine. We'd appreciate it if you")
        |> mes("brought as many as you can!")
        |> close()

      progress == 2 ->
        ctx
        |> mes("[Julian]")
        |> mes("You sure you want")
        |> mes("to work for someone")
        |> mes("like my boss? Can't")
        |> mes("you tell that she's")
        |> mes("evil? Escape from this")
        |> mes("place while you still can!")
        |> next()
        |> mes("[Alex]")
        |> mes("Julian...!")
        |> next()
        |> mes("[Julian]")
        |> mes("See what I mean?")
        |> close()

      progress == 3 ->
        ctx
        |> mes("[Julian]")
        |> mes("Wow, you must really")
        |> mes("like this kind of work,")
        |> mes("huh? I didn't really expect")
        |> mes("that you'd go to the shrine...")
        |> close()

      progress == 4 ->
        ctx
        |> mes("[Julian]")
        |> mes("I'm amazed to see you")
        |> mes("working so hard. You must")
        |> mes("like pleasing other people,")
        |> mes("I guess, but try not to be too")
        |> mes("kind. Wouldn't want that...")
        |> close()

      progress == 5 ->
        ctx
        |> mes("[Julian]")
        |> mes("Geez...")
        |> mes("You're a really nice")
        |> mes("person, you know that?")
        |> mes("Just try not to be taken")
        |> mes("for a sucker, okay?")
        |> close()

      true ->
        ctx
        |> mes("[Julian]")
        |> mes("Why are both of our")
        |> mes("team leaders so bull")
        |> mes("headed? Maybe it has")
        |> mes("something to do with")
        |> mes("them being old and single.")
        |> mes("Don't tell them I said that!")
        |> close()
    end
  end
end
