defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.MurinielSCottage do
  @moduledoc """
  Muriniel’s cottage reveals a recording to the stamp bearer.

  ## Behavior

  - Plays Muriniel’s recording and advances the doomed sword quest.

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
        map: "mjolnir_02",
        x: 170,
        y: 193,
        dir: 4,
        sprite: 111,
        name: "Muriniel's Cottage",
        scope: :shared,
        unique_name: "Muriniel's Cottage#juno"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :dmdswrd_Q, 0) do
      30 ->
        ctx
        |> mes("^3355FFMuriniel's pattern is carved into the wooden floor.^000000")
        |> next()
        |> mes(
          "^3355FFUsing the ^9999FFStamp of Muriniel^3355FF and the ^9999FFStamping Ink of Muriniel^3355FF, you fit the stamp into the pattern on the floor.^000000"
        )
        |> next()
        |> mes("^3355FF*Woon Woon*^000000")
        |> next()
        |> mes("^3355FFYou can faintly hear someone's voice softly in the distance.^000000")
        |> next()
        |> mes("[Muriniel's Recording]")
        |> mes("You, who are in the future, let me introduce myself.")
        |> next()
        |> mes("[Muriniel's Recording]")
        |> mes(
          "My name is Muriniel, the stamp craftman living in your past. I appreciate that you have overcome many obstacles to reach this place."
        )
        |> next()
        |> mes("[Muriniel's Recording]")
        |> mes(
          "However, you must first prove that you are qualified to wield the great power of the doomed sword."
        )
        |> next()
        |> mes("[Muriniel's Recording]")
        |> mes(
          "The great Sages in Juno have helped me to install this magical system in my cottage to leave my message to you, adventurer in the future."
        )
        |> next()
        |> mes("[Muriniel's Recording]")
        |> mes(
          "I know that you seek more power by obtaining a doomed sword. But not just anyone can handle the might of a doomed sword."
        )
        |> next()
        |> mes("[Muriniel's Recording]")
        |> mes(
          "And I shudder to think what would happen if such power were to fall into evil hands. The test I have prepared cannot begin until Autumn follows a hot summer."
        )
        |> next()
        |> mes("[Muriniel's Recording]")
        |> mes(
          "I shall give you an item that promises you of the quest I will give you in the future. Return to this place when the trees begin to shed their leaves..."
        )
        |> next()
        |> mes("[Muriniel's Recording]")
        |> mes("Until that time comes, prepare yourself. And stay alive.")
        |> next()
        |> mes("^3355FF*Bzzzt!*")
        |> mes("*Bzzzzzzt--*^000000")
        |> next()
        |> mes(
          "^3355FFSuddenly, the Stamp of Muriniel and the Compass of Muriniel break open to reveal a small, shining object.^000000"
        )
        |> next()
        |> mes("^3355FFYou have received the ^9999FFDignity of Muriniel^000000.")
        |> set_char_var(:dmdswrd_Q, 31)
        |> close()

      31 ->
        ctx
        |> mes("^3355FFYou can faintly hear someone's voice coming from somewhere...^000000")
        |> next()
        |> mes("[Muriniel's Recording]")
        |> mes(
          "Please remember to return to this place when the trees begin to shed their leaves. Until then, prepare yourself and stay alive."
        )
        |> close()

      _ ->
        ctx
        |> mes("'Muriniel's Cottage'")
        |> next()
        |> mes(
          "^3355FFFor some reason, that message is written in this place. But what could be so significant about a cottage like this?^000000"
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
