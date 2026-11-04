defmodule Aesir.ZoneServer.Content.Npc.Quests.BardQuest.LukeSSongsVol1 do
  @moduledoc """
  A book of songs by Luke of Izlude.

  ## Behavior

  Players with access can choose among three songs.

  ## Credits

  Original rAthena authors: Riotblade and L0ne_W0lf.
  Contributors: Lupus, SinSloth, and Euphy.

  ## Adaptation

  Transpiled by `mix aesir.import.npcs` and refactored with LLM assistance.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in01",
        x: 173,
        y: 96,
        dir: 0,
        sprite: 111,
        name: "Luke's Songs Vol.1",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :gef_bard_q, 0) > 11 do
      {ctx, choice} =
        ctx
        |> mes("[Preface]")
        |> mes(
          "I, Luke of Izlude, greatest of Bards in my time, leave the lyrics of my essential songs for posterity."
        )
        |> mes(" ")
        |> mes("Contents")
        |> next()
        |> select(["Wedding Song", "Life is a Water Mill", "We"])

      case choice do
        1 ->
          ctx
          |> mes("[Wedding Song]")
          |> mes("Prontera Sanctuary")
          |> mes("Is where all are heading")
          |> mes("To celebrate your union")
          |> mes("At your most happy wedding.")
          |> next()
          |> mes("[Wedding Song]")
          |> mes("With joy I strum my Lute")
          |> mes("As that is my trade")
          |> mes("To bring cheerful song")
          |> mes("To your wedding parade.")
          |> next()
          |> mes("[Wedding Song]")
          |> mes("For my songs, pay me")
          |> mes("Not Zeny or Gold,")
          |> mes("But the smile of the")
          |> mes("Bride, if I may")
          |> mes("be so bold.")
          |> next()
          |> mes("[Wedding Song]")
          |> mes("The glistening eyes")
          |> mes("Of a beautiful lass")
          |> mes("Those lustrous locks")
          |> mes("And that firm, supple--")
          |> next()
          |> mes("[Wedding Song]")
          |> mes("Forgive me, groom!")
          |> mes("But she's just so beautiful!")
          |> mes("May your union be blessed!")
          |> mes("Er, may your wife be dutiful.")
          |> next()
          |> mes("[Luke's Note]")
          |> mes(
            "This song is about a certain Bard who was invited to a wedding ceremony and could not resist the bride's beauty. He ended up singing a song of seduction."
          )
          |> next()
          |> mes("[Luke's Note]")
          |> mes("The lyrics, of course, are fictional, and are in no way anecdotal.")
          |> close()

        2 ->
          ctx
          |> mes("[Life is a Water Mill]")
          |> mes("I chased after fame.")
          |> mes("It eluded me.")
          |> mes("I ran after happiness")
          |> mes("But never caught it.")
          |> next()
          |> mes("[Life is a Water Mill]")
          |> mes("But tomorrow will still")
          |> mes("Be there, I'm sure.")
          |> mes("Like the Water Mill")
          |> mes("In Al De Baran")
          |> mes("Which turns as")
          |> mes("Life goes on.")
          |> next()
          |> mes("[Life is a Water Mill]")
          |> mes("Cheer up! Life goes on.")
          |> mes("As surely as the Water")
          |> mes("Mill turns, tomorrow")
          |> mes("Will come.")
          |> next()
          |> mes("[Luke's Note]")
          |> mes("This song was")
          |> mes("made to give comfort")
          |> mes("to people in despair.")
          |> close()

        3 ->
          ctx
          |> mes("[We]")
          |> mes("A good Bard sings")
          |> mes("To please his listener.")
          |> mes("So do not expect a sad song")
          |> mes("That deepens your anguish.")
          |> next()
          |> mes("[We]")
          |> mes("A good Dancer dances")
          |> mes("To please her audience.")
          |> mes("Shall we dance together?")
          |> mes("Just hold my hands.")
          |> mes("La la la~ La la la~")
          |> next()
          |> mes("[We]")
          |> mes("Towner: 'Then why the hell do you guys make discords sometimes?!'")
          |> mes("Bard: 'Well... Nobody's perfect!")
          |> next()
          |> mes("[Luke's Note]")
          |> mes(
            "This song is good to be sung during festivals, as the intentional discord encourages the audience to participate. Aside from that, this song is pretty meaningless."
          )
          |> close()

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Sketzi Bundin]")
      |> mes("I'm sorry, but that book is not available for public exhibition.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
