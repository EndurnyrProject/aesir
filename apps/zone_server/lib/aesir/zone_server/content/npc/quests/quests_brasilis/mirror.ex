defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Mirror do
  @moduledoc """
  The mirror reveals the ghost during the museum bathroom quest.

  ## Behavior

  - Reveals the ghost after the correct spell and quest progression.
  - Resolves the encounter with dice or an escape.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_in01",
        x: 151,
        y: 180,
        dir: 3,
        sprite: 844,
        name: "Mirror",
        scope: :shared,
        unique_name: "Mirror#bra"
      }
    ]

  alias Aesir.ZoneServer.Mmo.Emotion
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :brazil_ghost, 0) > 0 do
      {ctx, choice} =
        ctx
        |> mes("- You can see a clean mirror without any marks or dust -")
        |> next()
        |> select(["Examine it.", "Ignore."])

      case choice do
        1 ->
          examine(ctx)

        2 ->
          ctx |> mes("You do nothing.") |> close()

        _ ->
          ctx
      end
    else
      ctx |> mes("- You can see a clean mirror without any marks or dust -") |> close()
    end
  end

  defp examine(ctx) do
    {ctx, spell} =
      ctx |> mes("- What was the next line to that spell now? -") |> input(:string)

    ctx = ctx |> set_local(:"input$", spell) |> next()
    ctx = mes(ctx, "[#{char_name(ctx, 0)}]")

    ctx =
      ctx
      |> mes(get_local(ctx, :"input$", ""))
      |> next()
      |> set_local(:"braspell$", "Where are you mom?")

    ctx =
      set_local(
        ctx,
        :chkspell,
        Rathena.compare(get_local(ctx, :"braspell$", ""), get_local(ctx, :"input$", ""))
      )

    cond do
      not Rathena.truthy?(get_local(ctx, :chkspell, 0)) ->
        ctx |> mes("Seems like you said something wrong.") |> close()

      get_char_var(ctx, :brazil_ghost, 0) == 6 ->
        meet_ghost(ctx)

      true ->
        ctx |> mes("Nothing happens.") |> close()
    end
  end

  defp meet_ghost(ctx) do
    ctx =
      ctx
      |> mes("[Distant Sound]")
      |> mes("^FF0000kihe! hit! hit! hit! hit!^000000")
      |> next()
      |> mes("[Distant Sound]")
      |> mes("^FF0000kihe! hit! hit! hit! hit!^000000")
      |> mes("^FF0000kihe! hit! hit! hit! hit!^000000")
      |> next()
      |> mes("[Distant Sound]")
      |> mes("Behind you...")
      |> enablenpc("Ghost#bra")
      |> next()

    ctx = emotion(ctx, :huk, playerattached(ctx))

    {ctx, action} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("The stories about the ghost are true~!")
      |> next()
      |> mes("[Ghost]")
      |> mes("^FF0000my baby....^000000")
      |> next()
      |> mes("[Ghost]")
      |> mes("^FF0000I can't see.... my eye....^000000")
      |> mes("^FF0000What's going on....?^000000")
      |> next()
      |> mes(
        "- You take a deep breath and then look at the Ghost and notice it has an eye patch -"
      )
      |> next()
      |> mes("[Ghost]")
      |> mes("^FF0000My eyes are so tight... can you take this off?^000000")
      |> next()
      |> mes("You step carefully towards the ghost.")
      |> next()
      |> mes("His face was covered with dust making strange contortions with it's face.")
      |> next()
      |> mes("[Ghost]")
      |> mes("^FF0000Come on help mom.....^000000")
      |> next()
      |> select(["Take the eye bandage off.", "Run away~."])

    case action do
      1 ->
        ctx = roll_dice(ctx)

        if get_local(ctx, :cpudice, 0) > get_local(ctx, :pcdice, 0) do
          ctx
          |> specialeffect2(:devil)
          |> mes("[Ghost]")
          |> mes("^FF0000Go away!^000000")
          |> set_char_var(:brazil_ghost, 1)
          |> changequest(60_354, 2208)
          |> percent_heal(hp: -50, sp: -50)
          |> close()
          |> disablenpc("Ghost#bra")
          |> warp("bra_in01", 12, 183)
        else
          ctx
          |> emotion(:stare, playerattached(ctx))
          |> mes("[Ghost]")
          |> mes("^FF0000Ahh!^000000")
          |> mes("The Ghost disappeared into the toilet.")
          |> set_char_var(:brazil_ghost, 7)
          |> changequest(60_354, 60_355)
          |> close()
          |> disablenpc("Ghost#bra")
          |> warp("bra_in01", 206, 100)
        end

      2 ->
        ctx
        |> mes("You run away from the ghost.")
        |> close()
        |> set_char_var(:brazil_ghost, 1)
        |> changequest(60_354, 2208)
        |> warp("bra_in01", 12, 183)
        |> disablenpc("Ghost#bra")

      _ ->
        ctx
    end
  end

  defp roll_dice(ctx) do
    ctx = ctx |> set_local(:cpudice, Enum.random(1..6)) |> set_local(:pcdice, Enum.random(1..6))

    if get_local(ctx, :cpudice, 0) != get_local(ctx, :pcdice, 0) do
      ctx =
        emotion(ctx, Emotion.id(:otl) + get_local(ctx, :cpudice, 0), getnpcid(ctx, "Ghost#bra"))

      emotion(ctx, Emotion.id(:otl) + get_local(ctx, :pcdice, 0), playerattached(ctx))
    else
      roll_dice(ctx)
    end
  end
end
