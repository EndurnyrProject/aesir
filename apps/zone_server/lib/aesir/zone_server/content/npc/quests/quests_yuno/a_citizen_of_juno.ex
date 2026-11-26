defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.ACitizenOfJuno do
  @moduledoc """
  A citizen of Juno directs visitors and recognizes the Stamp of Muriniel.

  ## Behavior

  - Directs the stamp bearer to Yklah; otherwise describes Juno.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf
    - kobra_k88
    - Darkchild
    - Lupus
    - Samuray22
    - akrus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 157,
        y: 87,
        dir: 4,
        sprite: 102,
        name: "A Citizen of Juno",
        scope: :shared,
        unique_name: "A Citizen of Juno#juno"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Shalima]")
      |> mes(
        "When you go north from Al De Baran, you will arrive at 'Elmeth Plateau,' a place covered with molten rock."
      )
      |> next()
      |> mes("[Shalima]")
      |> mes(
        "On the top of a mountain connected to the plateau, you can find a bridge which leads you to this place!, ^3355FFJuno,^000000 the city of Sages."
      )
      |> next()

    if get_char_var(ctx, :dmdswrd_Q, 0) == 23 do
      ctx
      |> mes("[Shalima]")
      |> mes("Oh...?")
      |> mes("what is that shining object you're carrying with you? Isn't that...?")
      |> next()
      |> mes("[Shalima]")
      |> mes("The ^3355FFStamp of Muriniel^000000? What a surprise!")
      |> next()
      |> mes("[Shalima]")
      |> mes(
        "When you go East from the entrance of Juno, you will find the Street of Book Stores. If you have some time, please visit ^3355FFSir Yklah^000000 who is one of 3 well-known sages in Juno."
      )
      |> next()
      |> mes("[Shalima]")
      |> mes("I believe he may take some special interest in the Stamp you are carrying.")
      |> close()
    else
      ctx
      |> mes("[Shalima]")
      |> mes(
        "In Juno, you can visit places such as the 'Juphero Plaza,' 'Juno Conference Hall,' 'Schweicherbil Magic Academy', or the 'Monster Museum.' These places are famous around the world!"
      )
      |> next()
      |> mes("[Shalima]")
      |> mes(
        "You may also wish to drop by the 'Sage Castle,' where people can change their jobs into 'Sage,' one of the more unique classes."
      )
      |> next()
      |> mes("[Shalima]")
      |> mes("If you're interested in the Sage class, why don't you go look around the castle?")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
