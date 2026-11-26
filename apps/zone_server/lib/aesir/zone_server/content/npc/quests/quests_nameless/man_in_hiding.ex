defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.ManInHiding do
  @moduledoc """
  A fugitive shares his half of a treasure-opening spell.

  ## Behavior

  - Offers different conversations depending on the treasure hunt and Z Gang progress.
  - Gives the player the missing half of the spell.

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
        map: "comodo",
        x: 339,
        y: 224,
        dir: 3,
        sprite: 881,
        name: "Man in Hiding",
        scope: :shared,
        unique_name: "Man in Hiding#nd"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :treasure_nd, 0) < 7 ->
        ctx |> mes("[Man in Hiding]") |> mes("Whoa, don't get so close!") |> close()

      get_char_var(ctx, :treasure_nd, 0) == 7 or get_char_var(ctx, :treasure_nd, 0) == 8 ->
        if get_char_var(ctx, :zdan_edq, 0) > 12 do
          {ctx, _} =
            ctx
            |> mes("[Man in Hiding]")
            |> mes("Whoa, don't get so close!")
            |> next()
            |> select(["Why are you hiding here?"])

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Why are you hiding here?")
            |> mes("Didn't the Z Gang hire you")
            |> mes("to dig up some treasure?")
            |> next()
            |> mes("[Man in Hiding]")
            |> mes("Huh? Z Gang? Treasure?")
            |> next()
            |> mes("[Man in Hiding]")
            |> mes("Huh? Wait, tell me the")
            |> mes("truth. Did you actually")
            |> mes("meet the Z Gang?")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("I not only met the Z Gang,")
            |> mes("I also captured them. I've")
            |> mes("come looking for you to")
            |> mes("find out more about this")
            |> mes("buried treasure.")
            |> next()
            |> mes("[Man in Hiding]")
            |> mes("I get it now. You must")
            |> mes("have met that other guy")
            |> mes("they hired to get the")
            |> mes("treasure. Huh. He's got one")
            |> mes("half of the spell to open it,")
            |> mes("and I've got the other.")
            |> next()
            |> mes("[Man in Hiding]")
            |> mes("Well, you can have this,")
            |> mes("the rest of the magic spell.")
            |> mes("Let me warn you, though,")
            |> mes("there's something weird")
            |> mes("about the spell, and the")
            |> mes("treasure itself.")
            |> next()

          ctx =
            if get_char_var(ctx, :treasure_nd, 0) == 7 do
              ctx
              |> mes("^3355FFYou received a torn")
              |> mes("document that reads")
              |> mes("''^FF0000Seseame]^000000.''")
              |> set_char_var(:treasure_nd, 10)
              |> next()
            else
              ctx
              |> mes("^3355FFYou received a torn")
              |> mes("document that reads")
              |> mes("''^FF0000Treasure]^000000.''")
              |> set_char_var(:treasure_nd, 9)
              |> next()
            end

          ctx
          |> mes("[Man in Hiding]")
          |> mes("I don't understand why they")
          |> mes("went through the hassle of")
          |> mes("splitting this spell in two")
          |> mes("parts. There must be some")
          |> mes("reason. Whatever it is, it")
          |> mes("must be pretty important.")
          |> next()
          |> mes("[Man in Hiding]")
          |> mes("I guess maybe you need")
          |> mes("two people to move the")
          |> mes("treasure? Well, whatever.")
          |> mes("Good luck finding that")
          |> mes("treasure. Farewell now!")
          |> close()
        else
          {ctx, _} =
            ctx
            |> mes("[Man in Hiding]")
            |> mes("Whoa, don't get so close!")
            |> next()
            |> select(["Ask About Treasure"])

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("I've come looking")
            |> mes("for information")
            |> mes("about the treasure.")
            |> next()
            |> emotion(:huk)
            |> mes("[Man in Hiding]")
            |> mes("You... You've come")
            |> mes("looking for me?!")
            |> mes("Ugh, I'm cornered!")
            |> mes("I'm not going down")
            |> mes("without a fight!")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("What? No, it's not like")
            |> mes("that. I met this treasure")
            |> mes("hunter in Morocc that said")
            |> mes("I could find you around here.")
            |> next()
            |> mes("[Man in Hiding]")
            |> mes("Treasure hunter...?")
            |> mes("Oh, then you already")
            |> mes("know about the treasure...")
            |> next()
            |> mes("[Man in Hiding]")
            |> mes("If I'm right, then you")
            |> mes("need the other half of")
            |> mes("the spell to open the")
            |> mes("treasure. Here, you can")
            |> mes("take it. I have no use")
            |> mes("for it, anyway.")
            |> next()

          ctx =
            if get_char_var(ctx, :treasure_nd, 0) == 7 do
              ctx
              |> mes("^3355FFYou received a torn")
              |> mes("document that reads")
              |> mes("''^FF0000Sesame]^000000.''")
              |> set_char_var(:treasure_nd, 10)
              |> next()
            else
              ctx
              |> mes("^3355FFYou received a torn")
              |> mes("document that reads")
              |> mes("''^FF0000Treasure]^000000.''")
              |> set_char_var(:treasure_nd, 9)
              |> next()
            end

          ctx
          |> mes("[Man in Hiding]")
          |> mes("Now would you just get")
          |> mes("out of here? If you couldn't")
          |> mes("already tell, I'm hiding from")
          |> mes("some people. I told you all")
          |> mes("I know, so do me a favor,")
          |> mes("and don't tell anyone I'm here!")
          |> close()
        end

      get_char_var(ctx, :treasure_nd, 0) == 9 ->
        ctx =
          ctx
          |> mes("[Man in Hiding]")
          |> mes("Aren't you going to")
          |> mes("dig up that treasure?")
          |> mes("You have both parts of")
          |> mes("the spell that you need:")
          |> mes("I already gave you the")
          |> mes("''^FF0000Treasure]^000000'' part, right?")
          |> next()

        if get_char_var(ctx, :zdan_edq, 0) > 12 do
          ctx
          |> mes("[Man in Hiding]")
          |> mes("Anyway, now that the")
          |> mes("Z Gang is captured,")
          |> mes("it might be safe enough")
          |> mes("for me to go back home.")
          |> close()
        else
          ctx
          |> mes("[Man in Hiding]")
          |> mes("Would you do me a favor,")
          |> mes("and just get out of here")
          |> mes("before someone finds")
          |> mes("my hiding place?")
          |> close()
        end

      get_char_var(ctx, :treasure_nd, 0) == 10 ->
        ctx =
          ctx
          |> mes("[Man in Hiding]")
          |> mes("Aren't you going to")
          |> mes("dig up that treasure?")
          |> mes("You have both parts of")
          |> mes("the spell that you need:")
          |> mes("I already gave you the")
          |> mes("''^FF0000Sesame]^000000'' part, right?")
          |> next()

        if get_char_var(ctx, :zdan_edq, 0) > 12 do
          ctx
          |> mes("[Man in Hiding]")
          |> mes("Anyway, now that the")
          |> mes("Z Gang is captured,")
          |> mes("it might be safe enough")
          |> mes("for me to go back home.")
          |> close()
        else
          ctx
          |> mes("[Man in Hiding]")
          |> mes("Would you do me a favor,")
          |> mes("and just get out of here")
          |> mes("before someone finds")
          |> mes("my hiding place?")
          |> close()
        end

      true ->
        ctx
        |> mes("[Man in Hiding]")
        |> mes("Heh! Looks like it's")
        |> mes("safe for me to come out")
        |> mes("of hiding, and just go home!")
        |> mes("But maybe I should stick")
        |> mes("around here a little longer,")
        |> mes("just to be on the safe side.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
