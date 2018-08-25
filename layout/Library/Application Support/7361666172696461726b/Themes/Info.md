# Making themes

1. Themes should be installed to the /Library/Application Support/7361666172696461726b/Themes/ folder

2. Themes are .css files, any other file extensions are ignored

3. On the first line of the file, there should be a comment with the host of the site that the theme is to be loaded on:
`/* www.host.com */` for a single host, or `/* www.host.com, www.host2.com, ...*/` for multiple. Beware that some hosts use *www.* and others don't. You need to make sure that you get the correct host.

### Nebula language differences

While Nebula doesn't change any normal CSS, there are some additions to the language, mainly to allow custom styles to feel more integrated.

`NEBULA_DARK` is the chosen background colour.

`NEBULA_TEXT` is the chosen text colour.

`NEBULA_DARKER` is a darker version of `NEBULA_DARK`. This is a set amount darker, so you cannot change its value.
