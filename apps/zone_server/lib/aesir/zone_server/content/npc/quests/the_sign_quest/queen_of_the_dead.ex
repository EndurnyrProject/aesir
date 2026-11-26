defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.QueenOfTheDead do
  @moduledoc """
  The Queen of the Dead aids favored adventurers on the Sign quest.

  ## Behavior

  - Punishes uninvited visitors and rewards the hero with a symbol.
  - Transforms the Sobbing Starlight after the hero lends it to her.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_sign01",
        x: 45,
        y: 227,
        dir: 4,
        sprite: 856,
        name: "Queen of the Dead",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Lady Hell]")

    cond do
      get_char_var(ctx, :sign_q, 0) < 117 ->
        ctx
        |> mes("^8C1717You wish to have")
        |> mes("an audience with the")
        |> mes("Queen of the Dead without")
        |> mes("invitation? Insolent mortal!")
        |> mes("Go back to where you belong!^000000")
        |> close2()
        |> percent_heal(hp: -100, sp: 0)

      get_char_var(ctx, :sign_q, 0) == 117 ->
        {ctx, _} =
          ctx
          |> mes("^8C1717I have been told")
          |> mes("by Ganglati that you")
          |> mes("are the mortal that has")
          |> mes("guided Mother's soul to me.^000000")
          |> next()
          |> mes("[Lady Hell]")
          |> mes("^8C1717Do not fear me,")
          |> mes("hero of Midgard.")
          |> mes("You have won the favor")
          |> mes("of the Queen of the Dead")
          |> mes("and may ask me of any")
          |> mes("reward if I deem it fair.^000000")
          |> next()
          |> select(["The Symbol of the Nine Realms..."])

        ctx
        |> mes("[Lady Hell]")
        |> mes("^8C1717The true Symbol of the")
        |> mes("Nine Realms cannot be freely")
        |> mes("given or lent. However, I sense")
        |> mes("your purpose and will give you")
        |> mes("a symbol imbued with enough")
        |> mes("power to be used only once.^000000")
        |> next()
        |> mes("[Lady Hell]")
        |> mes("^8C1717With the symbol I give you,")
        |> mes("you can command the dead to")
        |> mes("carry out your will without")
        |> mes("question. However, keep in")
        |> mes("mind that after one use,")
        |> mes("its power will be consumed.^000000")
        |> next()
        |> mes("[Lady Hell]")
        |> mes("^8C1717I have also decided")
        |> mes("to reward you with one")
        |> mes("more special permission.")
        |> mes("You may now freely draw")
        |> mes("water from the fountain")
        |> mes("in my mansion, brave hero.^000000")
        |> next()
        |> mes("^3355FFYou received the")
        |> mes("Symbol of the Nine Realms.^000000")
        |> delitem(7307, 1)
        |> set_char_var(:sign_q, 118)
        |> give_item(7305, 1)
        |> close()

      get_char_var(ctx, :sign_q, 0) < 142 ->
        ctx
        |> mes("^8C1717Greetings, mortal.")
        |> mes("Make sure that you")
        |> mes("use the power of the")
        |> mes("symbol wisely. You will")
        |> mes("be responsible for the")
        |> mes("consequences...^000000")
        |> close()

      get_char_var(ctx, :sign_q, 0) == 142 ->
        ctx = ctx |> mes("^8C1717Ah.") |> mes("You are the") |> mes("mortal called")

        {ctx, choice} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), ", are you not?"))
          |> mes("Yes, you are known to me.^000000")
          |> next()
          |> mes("[Lady Hell]")
          |> mes("^8C1717I've wanted to see you")
          |> mes("as I've sensed that you")
          |> mes("carry something which feels")
          |> mes("very familiar to me. Do you")
          |> mes("have something extraordinarily")
          |> mes("special in your possession?^000000")
          |> next()
          |> select(["The Sign", "Sobbing Starlight"])

        case choice do
          1 ->
            ctx
            |> mes("[Lady Hell]")
            |> mes("^8C1717The Sign...?")
            |> mes("Hmm, no, that's not")
            |> mes("what I sensed. It's actually")
            |> mes("something quite different...^000000")
            |> close()

          2 ->
            ctx =
              ctx
              |> mes("[Lady Hell]")
              |> mes("^8C1717Yes, that's it!")
              |> mes("I never expected a mortal")
              |> mes("to have such an interesting")

            {ctx, response} =
              ctx
              |> mes(
                Rathena.concat(
                  Rathena.concat(
                    "artifact in ",
                    if(sex(ctx) == 1, do: "his", else: "her")
                  ),
                  " possession.^000000"
                )
              )
              |> next()
              |> mes("[Lady Hell]")
              |> mes("^8C1717As queen of Niflheim,")
              |> mes("I command you to lend the")
              |> mes("Sobbing Starlight to me! Fear")
              |> mes("not, I shall quickly return it. For a mortal, it must have")
              |> mes("taken great pains to obtain this...^000000")
              |> next()
              |> select(["Please take it...", "N-no! Don't take it!"])

            case response do
              1 ->
                ctx
                |> mes("[Lady Hell]")
                |> mes("^8C1717Thank you mortal.")
                |> mes("Now, I shall show")
                |> mes("you something truly")
                |> mes("interesting...^000000")
                |> delitem(7178, 1)
                |> set_char_var(:sign_q, 143)
                |> close()

              2 ->
                ctx
                |> mes("[Lady Hell]")
                |> mes("^8C1717Ha ha ha!")
                |> mes("You amuse me,")
                |> mes("mortal! To think,")
                |> mes("you even have courage")
                |> mes("to refuse the queen of")
                |> mes("Niflheim! Ha ha ha!^000000")
                |> next()
                |> mes("[Lady Hell]")
                |> mes("^8C1717Mercy is not a quality")
                |> mes("that I am known for, but")
                |> mes("since you are my favored")
                |> mes("mortal, I shall not kill you.")
                |> mes("Still, it would be unwise")
                |> mes("to displease me~^000000")
                |> close2()
                |> warp("niflheim", 29, 154)

              _ ->
                ctx
            end

          _ ->
            ctx
        end

      get_char_var(ctx, :sign_q, 0) == 143 ->
        ctx
        |> mes("^8C1717As queen of this realm,")
        |> mes("I am unaccustomed to labor.")
        |> mes("But give me a moment to finish")
        |> mes("my work on this priceless")
        |> mes("artifact, mortal.^000000")
        |> next()
        |> specialeffect(:glasswall)
        |> next()
        |> specialeffect(:napalmbeat)
        |> next()
        |> specialeffect(:firepillarbomb)
        |> next()
        |> specialeffect(:lord)
        |> next()
        |> mes("[Lady Hell]")
        |> mes("^8C1717It is done.")
        |> mes("This is the true")
        |> mes("form of the object")
        |> mes("you humans call the")
        |> mes("Sobbing Starlight.^000000")
        |> next()
        |> set_char_var(:sign_q, 144)
        |> give_item(7025, 1)
        |> mes("[Lady Hell]")
        |> mes("^8C1717Although you may also know")
        |> mes(
          "this object as God's Tear Drop, keep in mind that history, as you humans know it, may actually be different than the truth.^000000"
        )
        |> next()
        |> mes("[Lady Hell]")
        |> mes("^8C1717In other words, there")
        |> mes("are some older tales about")
        |> mes("the gods and their enemies that")
        |> mes(
          "may have been confused and twisted as they were handed down from generation to generation.^000000"
        )
        |> next()
        |> mes("[Lady Hell]")
        |> mes("^8C1717That is all I can tell")
        |> mes("you for now, mortal. It will")
        |> mes("be your job to discover the")
        |> mes("truth of the legends...^000000")
        |> close()

      true ->
        ctx
        |> mes("^8C1717Greetings, mortal.")
        |> mes("Is the realm of the living")
        |> mes("that boring and tedious?")
        |> mes("Ha ha ha! Well, there shall")
        |> mes("always be a place for you")
        |> mes("here in Niflheim.^000000")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
