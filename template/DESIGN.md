---
name: Artisanal Draught
colors:
  surface: '#1c110a'
  surface-dim: '#1c110a'
  surface-bright: '#45362d'
  surface-container-lowest: '#160c06'
  surface-container-low: '#251911'
  surface-container: '#291d15'
  surface-container-high: '#35271f'
  surface-container-highest: '#403229'
  on-surface: '#f6ded1'
  on-surface-variant: '#d6c3b5'
  inverse-surface: '#f6ded1'
  inverse-on-surface: '#3b2d25'
  outline: '#9e8e81'
  outline-variant: '#51443a'
  surface-tint: '#fbb97b'
  primary: '#fbb97b'
  on-primary: '#4b2800'
  primary-container: '#d4975c'
  on-primary-container: '#583000'
  inverse-primary: '#84531e'
  secondary: '#e3bfb2'
  on-secondary: '#422b22'
  secondary-container: '#5d4339'
  on-secondary-container: '#d4b1a4'
  tertiary: '#ccc6be'
  on-tertiary: '#33302b'
  tertiary-container: '#a8a39c'
  on-tertiary-container: '#3c3934'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdcbf'
  primary-fixed-dim: '#fbb97b'
  on-primary-fixed: '#2d1600'
  on-primary-fixed-variant: '#693c07'
  secondary-fixed: '#ffdbce'
  secondary-fixed-dim: '#e3bfb2'
  on-secondary-fixed: '#2a170f'
  on-secondary-fixed-variant: '#5a4137'
  tertiary-fixed: '#e8e1da'
  tertiary-fixed-dim: '#ccc6be'
  on-tertiary-fixed: '#1e1b17'
  on-tertiary-fixed-variant: '#4a4641'
  background: '#1c110a'
  on-background: '#f6ded1'
  surface-variant: '#403229'
typography:
  display-lg:
    fontFamily: Playfair Display
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Playfair Display
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Playfair Display
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Playfair Display
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Open Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Open Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Open Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Open Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  container-padding-mobile: 20px
  container-padding-desktop: 40px
  gutter: 16px
  stack-sm: 12px
  stack-md: 24px
  stack-lg: 48px
---

## Brand & Style

The design system is centered on the concept of "The Modern Speakeasy." It targets beer enthusiasts and connoisseurs who value craftsmanship, heritage, and the sensory experience of discovery. The visual narrative balances the rustic warmth of a boutique brewery with the sophisticated precision of a high-end digital tool.

The design style is a hybrid of **Minimalism** and **Tactile/Skeuomorphism**. We lean into high-quality typography and generous whitespace to maintain a premium feel, while employing subtle textures and "soft glow" amber accents to mimic the atmosphere of a dimly lit, upscale taproom. The emotional response should be one of comfort, exclusivity, and curiosity.

## Colors

This design system utilizes a palette inspired by the brewing process:
- **Primary (Golden Amber):** Used for highlights, active states, and primary actions. It represents the liquid itself and provides a warm glow against the dark background.
- **Secondary (Rich Brown):** Used for surface levels and containers, reminiscent of aged wood and roasted malts.
- **Tertiary (Cream):** Reserved for high-contrast text and delicate accents, providing a crisp, legible "head" to the dark base.
- **Neutral (Deep Charcoal):** The foundation of the UI, providing a deep, immersive background that allows the amber tones to pop.

Apply a 5% opacity "Golden Amber" glow to primary buttons and active navigation elements to simulate light passing through a glass of beer.

## Typography

The typography strategy employs a high-contrast pairing to evoke "Artisanal Authority." 

**Playfair Display** is used for all editorial content, titles, and brand moments. It should be set with tighter letter-spacing in larger sizes to emphasize its elegant, high-contrast strokes. 

**Open Sans** handles the functional heavy lifting. It provides a clean, neutral balance to the expressive serif, ensuring that technical beer specifications (ABV, IBU, SRM) remain highly legible at small sizes. All labels use an uppercase treatment with expanded tracking to create a "curated" look.

## Layout & Spacing

The design system follows a **fluid grid** model with a strong emphasis on vertical rhythm. 

- **Mobile:** 4-column grid with 20px margins.
- **Tablet:** 8-column grid with 32px margins.
- **Desktop:** 12-column grid with a max-width of 1280px and 40px margins.

Spacing should be generous to maintain the premium feel. Use "Stack" units for vertical relationships: `stack-sm` for related items (label to input), `stack-md` for component spacing (card to card), and `stack-lg` for section breaks. Content should feel "unhurried," avoiding information density in favor of high-quality imagery and clear focal points.

## Elevation & Depth

Depth is conveyed through **Tonal Layers** and **Ambient Glows** rather than traditional shadows.

1.  **Level 0 (Base):** Deep Charcoal (#1A0F08).
2.  **Level 1 (Cards/Surfaces):** Rich Brown (#2C1810) with a 1px inner border in 10% Cream to define edges.
3.  **Level 2 (Interactive):** Surfaces that are lifted or active should feature a subtle outer glow using the Primary Amber color at 15% opacity with a 20px blur.

Avoid pitch-black shadows. Instead, use "Umbra" layers that are slightly darker versions of the background color to maintain the warm, organic feel of the palette.

## Shapes

The shape language is "Softly Crafted." We avoid the clinical feel of sharp corners and the playfulness of full pills. 

The standard radius is **0.5rem (8px)** for buttons and inputs, which feels modern yet grounded. Larger containers like product cards or modals use **1rem (16px)** to create a sense of enclosure and comfort. This softened geometry mimics the curves of glassware and barrel staves.

## Components

### Buttons
Primary buttons are filled with Golden Amber, featuring Cream text for maximum contrast. They should have a subtle radial gradient (lighter in the center) to suggest the luminosity of a poured beer. Secondary buttons use a Rich Brown fill with a 1px Amber outline.

### Input Fields
Inputs are dark-themed with a subtle 1px border in 20% Cream. On focus, the border transitions to Golden Amber with a soft 4px outer glow. Labels are always positioned above the field in `label-md` uppercase style.

### Cards
Cards are the primary vehicle for beer discovery. They use the Rich Brown background with high-quality, desaturated photography. A subtle 1px "Gold Wire" border (Primary Amber at 30% opacity) may be used for featured selections.

### Icons
Icons must be **thin-line (1.5px stroke)**. Use "Gold-accented" styles where the primary action or active state of an icon is rendered in Golden Amber, while the inactive state is Cream at 60% opacity.

### Chips & Tags
Used for beer styles (e.g., "IPA," "Stout"). These should be low-profile: a simple Rich Brown background with a thin Golden Amber border and `label-sm` text.