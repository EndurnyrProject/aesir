defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.UtanKid do
  @moduledoc """
  Seeks a donation to repair Haatan's parents' house after a lightning strike.

  ## Behavior

  - Speaks intelligibly only after Umbalan language progress reaches stage 3.
  - Accepts 1,000 zeny only when the visitor has more than 1,000 zeny.
  - Attempts to give one Meat when carrying capacity permits, but keeps the donation either way.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "umbala",
        x: 70,
        y: 106,
        dir: 3,
        sprite: 781,
        name: "Utan Kid",
        scope: :shared,
        unique_name: "Utan Kid#um"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :event_umbala, 0) >= 3 do
      request_donation(ctx)
    else
      request_donation_in_umbalan(ctx)
    end
  end

  defp request_donation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[???]")
      |> mes("Huh?")
      |> mes("You're not one of us, are you?")
      |> next()
      |> mes("[???]")
      |> mes("Heh! Hi!")
      |> mes("My name is Haatan.")
      |> emotion(:smile)
      |> next()
      |> mes("[Haatan]")
      |> mes("...*Sigh*")
      |> mes("I am sorry, but I cannot play with")
      |> mes("you right now. My parent's house")
      |> mes("was struck by lightning yesterday")
      |> mes("and it burned down our roof...")
      |> emotion(:cry)
      |> next()
      |> mes("[Haatan]")
      |> mes(" . . . !")
      |> next()
      |> mes("[Haatan]")
      |> mes("Oh yes! Could you help me?")
      |> mes("You look pretty well off...")
      |> mes("Can donate some money for")
      |> mes("re-constructing my parents' house?")
      |> mes("You Rune-Midgartsians are all")
      |> mes("richer than Utans! I beg you!")
      |> emotion(:smile)
      |> next()
      |> select(["(Nod head)", "(Shake head)"])

    if choice == 1 do
      accept_donation(ctx)
    else
      ctx |> mes("[Haatan]") |> mes(".............*Sob*...") |> emotion(:cry) |> close()
    end
  end

  defp request_donation_in_umbalan(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[???]")
      |> mes("Umbah?")
      |> mes("Umbala umbabah umbah?")
      |> next()
      |> mes("[???]")
      |> mes("Umbah! Umbaumbah!")
      |> mes("Umbahumbah Haatan babah.")
      |> emotion(:cry)
      |> next()
      |> mes("[Haatan]")
      |> mes("........umbah,")
      |> mes("Umbah umbah umbaumbumbah umbah umbah")
      |> mes("Babaum babahum woombah umbah umbabah")
      |> mes("Umbah umbah")
      |> mes("..Umbah umbabah umbah...")
      |> emotion(:smile)
      |> next()
      |> mes("[Haatan]")
      |> mes(" . . . !")
      |> next()
      |> mes("[Haatan]")
      |> mes("Umbah!")
      |> mes("Umbah umbah? Umbah umbahbah")
      |> mes("abaum babahum woombah!")
      |> mes("Umbahumbah umbabahumbaumhumbah! Umbah!")
      |> emotion(:smile)
      |> next()
      |> select(["(Nod head)", "(Shake head)"])

    if choice == 1 do
      accept_donation_in_umbalan(ctx)
    else
      ctx |> mes("[Haatan]") |> mes("........umbah..") |> emotion(:smile) |> close()
    end
  end

  defp accept_donation(ctx) do
    ctx =
      ctx
      |> mes("[Haatan]")
      |> mes("Whoaaaa!!")
      |> mes("You the man~!")
      |> mes("Thank you so much, yay~!")

    if zeny(ctx) > 1000 do
      ctx
      |> collect_donation()
      |> next()
      |> mes("[Haatan]")
      |> mes("Thank you so much!")
      |> emotion(:smile)
      |> close()
    else
      ctx
      |> next()
      |> mes("[Haatan]")
      |> mes("Uh...")
      |> mes("It looks like...")
      |> mes("You don't have much")
      |> mes("yourself...")
      |> emotion(:hng)
      |> close()
    end
  end

  defp accept_donation_in_umbalan(ctx) do
    ctx =
      ctx
      |> mes("[Haatan]")
      |> mes("Umbaumbah!!")
      |> mes("Um~bahumbah~ Um~baumbah~")
      |> mes("Um~baumbah~ um~baumbah~")

    if zeny(ctx) > 1000 do
      ctx
      |> collect_donation()
      |> next()
      |> mes("[Haatan]")
      |> mes("Umba umba umbaum.")
      |> emotion(:cry)
      |> close()
    else
      ctx
      |> next()
      |> mes("[Haatan]")
      |> mes("...umbah? Umbahumbah!! Umbaum!")
      |> emotion(:hng)
      |> close()
    end
  end

  defp collect_donation(ctx) do
    ctx = pay_zeny(ctx, 1000)

    ctx =
      if Rathena.truthy?(checkweight(ctx, [{517, 1}])) do
        give_item(ctx, 517, 1)
      else
        ctx
      end

    emotion(ctx, :profusely_sweat)
  end
end
