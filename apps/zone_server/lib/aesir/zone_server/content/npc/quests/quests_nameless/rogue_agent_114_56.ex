defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.RogueAgent11456 do
  @moduledoc """
  A Rogue agent gathers reports on rumors in Al De Baran.

  ## Behavior

  - Gives the player a report and updates the rumor quest according to Z Gang progress.
  - Reminds the player where to deliver it or responds to later quest stages.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """
  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 114,
        y: 56,
        dir: 5,
        sprite: 828,
        name: "Rogue Agent",
        scope: :shared,
        unique_name: "Rogue Agent#nd0"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :rumour_nd, 0) < 3 do
      ctx
      |> mes("[Agent]")
      |> mes("Listen, I'm working on")
      |> mes("an important assignment")
      |> mes("for the Rogue Guild.")
      |> mes("Would let lemme alone")
      |> mes("so I can do what I gotta?")
      |> close()
    else
      cond do
        get_char_var(ctx, :rumour_nd, 0) == 3 ->
          if get_char_var(ctx, :zdan_edq, 0) > 12 do
            ctx
            |> mes("[Agent]")
            |> mes("They sent you to help me?")
            |> mes("Eh, thanks for comin' so")
            |> mes("far. I've been collecting")
            |> mes("intel here in Al De Baran.")
            |> mes("I'm pretty sure the Z Gang's")
            |> mes("spreading rumors around here.")
            |> next()
            |> mes("[Agent]")
            |> mes("They've been telling")
            |> mes("people there's gonna be")
            |> mes("a war comin', but... It")
            |> mes("seems like a load of huey.")
            |> mes("The Z Gang's captured so")
            |> mes("the rumor'll just die out...")
            |> next()
            |> mes("[Agent]")
            |> mes("Do me a favor, and")
            |> mes("get this report over")
            |> mes("the agent in Geffen?")
            |> mes("Thanks, I'd appreciate it.")
            |> next()
            |> mes("^3355FFYou received a")
            |> mes("tightly folded note.^000000")
            |> set_char_var(:rumour_nd, 4)
            |> close()
          else
            ctx
            |> mes("[Agent]")
            |> mes("They sent you to help me?")
            |> mes("Eh, thanks for comin' so")
            |> mes("far. I've been collecting")
            |> mes("intel here in Al De Baran.")
            |> next()
            |> mes("[Agent]")
            |> mes("There's this rumor goin'")
            |> mes("around that war's comin'")
            |> mes("but... I don't see any real")
            |> mes("signs of it. Trains, teleports,")
            |> mes("airships, they still keep")
            |> mes("on doin' what they do.")
            |> next()
            |> mes("[Agent]")
            |> mes("I'm not sure who, but")
            |> mes("someone's probably just")
            |> mes("spreading this rumor to")
            |> mes("get people to panick.")
            |> mes("It's kinda workin', though...")
            |> next()
            |> mes("[Agent]")
            |> mes("Do me a favor, and")
            |> mes("get this report over")
            |> mes("the agent in Geffen?")
            |> mes("Thanks, I'd appreciate it.")
            |> next()
            |> mes("^3355FFYou received a")
            |> mes("tightly folded note.^000000")
            |> set_char_var(:rumour_nd, 24)
            |> close()
          end

        get_char_var(ctx, :rumour_nd, 0) == 4 or get_char_var(ctx, :rumour_nd, 0) == 24 ->
          ctx = ctx |> mes("[Agent]") |> mes("Hey...")

          if get_char_var(ctx, :rumour_nd, 0) == 4 do
            ctx
            |> mes("Would you please get")
            |> mes("my report over to the")
            |> mes("Rogue agent in Geffen?")
            |> mes("You'd better hurry since")
            |> mes("we gotta work quick.")
            |> close()
          else
            ctx
            |> mes("Would you please get")
            |> mes("my report over to the")
            |> mes("Rogue Guild? They")
            |> mes("need to read it A.S.A.P.")
            |> mes("You know, pronto.")
            |> close()
          end

        true ->
          cond do
            get_char_var(ctx, :rumour_nd, 0) == 16 ->
              ctx
              |> mes("[Agent]")
              |> mes("What's this, a report")
              |> mes("from the Payon agent?")
              |> mes("Um, listen, I don't think")
              |> mes("this is for me. You might")
              |> mes("wanna try one of the other")
              |> mes("Rogue agents around, okay?")
              |> set_char_var(:rumour_nd, 17)
              |> close()

            get_char_var(ctx, :rumour_nd, 0) > 21 ->
              if get_char_var(ctx, :zdan_edq, 0) > 12 do
                ctx
                |> mes("[Agent]")
                |> mes("Hey, thanks for")
                |> mes("helping out. I sure")
                |> mes("hope the kingdom can")
                |> mes("enjoy a little peace")
                |> mes("with the Z Gang out")
                |> mes("of the picture.")
                |> close()
              else
                ctx
                |> mes("[Agent]")
                |> mes("Well, we've tracked")
                |> mes("down the Z Gang. All we")
                |> mes("gotta do now is get them!")
                |> close()
              end

            true ->
              ctx
              |> mes("[Agent]")
              |> mes("I still got some")
              |> mes("things to do around")
              |> mes("here. Them's the breaks.")
              |> close()
          end
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
